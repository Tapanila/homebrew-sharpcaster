#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="Tapanila"
REPO_NAME="SharpCaster"
RELEASES_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases"
FORMULA_PATH="Formula/sharpcaster.rb"
README_PATH="README.md"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

# prefer sha256sum, fallback to shasum -a 256
SHA256=""
if command -v sha256sum >/dev/null 2>&1; then
  SHA256="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA256="shasum -a 256"
else
  echo "Missing sha256 utility (sha256sum or shasum)" >&2
  exit 1
fi

echo "Fetching releases from ${RELEASES_API} ..."
releases_json=$(curl -fsSL "$RELEASES_API")

# pick the newest non-draft release (includes prereleases)
release=$(echo "$releases_json" | jq -r '[ .[] | select(.draft==false) ] | sort_by(.created_at) | reverse | .[0]')

if [[ -z "$release" || "$release" == "null" ]]; then
  echo "No suitable release found" >&2
  exit 0
fi

tag=$(echo "$release" | jq -r .tag_name)
name=$(echo "$release" | jq -r .name)
version="$tag"
version_no_v="${version#v}"  # Remove 'v' prefix if present

echo "Latest release: tag=${tag} name=${name} version=${version}"

# Map assets
assets=$(echo "$release" | jq -r '.assets[] | {name: .name, url: .browser_download_url} | @base64')

declare -A URLS

for encoded in $assets; do
  line=$(echo "$encoded" | base64 --decode)
  aname=$(echo "$line" | jq -r .name)
  aurl=$(echo "$line" | jq -r .url)
  case "$aname" in
    *osx-arm64*.tar.gz)   URLS[osx_arm64]="$aurl" ;;
    *osx-x64*.tar.gz)     URLS[osx_x64]="$aurl" ;;
    *linux-arm64*.tar.gz) URLS[linux_arm64]="$aurl" ;;
    *linux-x64*.tar.gz)   URLS[linux_x64]="$aurl" ;;
  esac
done

for key in osx_arm64 osx_x64 linux_arm64 linux_x64; do
  if [[ -z "${URLS[$key]:-}" ]]; then
    echo "Missing asset for $key in release $tag" >&2
    echo "Available assets:" >&2
    echo "$release" | jq -r '.assets[].name' >&2
    exit 1
  fi
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

declare -A SHAS
for key in osx_arm64 osx_x64 linux_arm64 linux_x64; do
  url="${URLS[$key]}"
  out="$tmpdir/${key}.tar.gz"
  echo "Downloading $key asset ..."
  curl -fsSL "$url" -o "$out"
  if [[ "$SHA256" == "sha256sum" ]]; then
    sha=$(sha256sum "$out" | awk '{print $1}')
  else
    sha=$(shasum -a 256 "$out" | awk '{print $1}')
  fi
  SHAS[$key]="$sha"
done

# Build new formula content
read -r -d '' NEW_FORMULA <<'RUBY'
class Sharpcaster < Formula
  desc "Cross-platform C# console application for interacting with Google Chromecast devices"
  homepage "https://github.com/Tapanila/SharpCaster"
  version "__VERSION__"
  license "MIT"

  if OS.mac? && Hardware::CPU.arm?
    url "__URL_OSX_ARM64__"
    sha256 "__SHA_OSX_ARM64__"
  elsif OS.mac? && Hardware::CPU.intel?
    url "__URL_OSX_X64__"
    sha256 "__SHA_OSX_X64__"
  elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
    url "__URL_LINUX_ARM64__"
    sha256 "__SHA_LINUX_ARM64__"
  elsif OS.linux? && Hardware::CPU.intel?
    url "__URL_LINUX_X64__"
    sha256 "__SHA_LINUX_X64__"
  end

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"sharpcaster" => "sharpcaster"
  end

  test do
    system "#{bin}/sharpcaster", "--version"
  end
end
RUBY

NEW_FORMULA=${NEW_FORMULA/__VERSION__/$version}
NEW_FORMULA=${NEW_FORMULA/__URL_OSX_ARM64__/${URLS[osx_arm64]}}
NEW_FORMULA=${NEW_FORMULA/__SHA_OSX_ARM64__/${SHAS[osx_arm64]}}
NEW_FORMULA=${NEW_FORMULA/__URL_OSX_X64__/${URLS[osx_x64]}}
NEW_FORMULA=${NEW_FORMULA/__SHA_OSX_X64__/${SHAS[osx_x64]}}
NEW_FORMULA=${NEW_FORMULA/__URL_LINUX_ARM64__/${URLS[linux_arm64]}}
NEW_FORMULA=${NEW_FORMULA/__SHA_LINUX_ARM64__/${SHAS[linux_arm64]}}
NEW_FORMULA=${NEW_FORMULA/__URL_LINUX_X64__/${URLS[linux_x64]}}
NEW_FORMULA=${NEW_FORMULA/__SHA_LINUX_X64__/${SHAS[linux_x64]}}

# Update formula if changed
if [[ ! -f "$FORMULA_PATH" ]] || ! diff -q <(printf "%s" "$NEW_FORMULA") "$FORMULA_PATH" >/dev/null 2>&1; then
  echo "Updating $FORMULA_PATH ..."
  printf "%s\n" "$NEW_FORMULA" > "$FORMULA_PATH"
  changed=1
else
  echo "Formula already up to date."
  changed=0
fi

# Update README version line
if [[ -f "$README_PATH" ]]; then
  if grep -qE '^- \*\*Version\*\*: ' "$README_PATH"; then
    sed -i.bak -E "s/^(- \*\*Version\*\*: ).*$/\\1$version_no_v/" "$README_PATH"
    rm -f "$README_PATH.bak"
  fi
fi

# Commit and push if anything changed
if ! git diff --quiet; then
  echo "Committing changes ..."
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add "$FORMULA_PATH" "$README_PATH" || true
  git commit -m "chore: update sharpcaster formula to ${version} (${tag})"
  git push
else
  echo "No changes to commit."
fi

echo "Done."
