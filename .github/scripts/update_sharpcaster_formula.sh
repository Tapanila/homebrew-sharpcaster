#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="Tapanila"
REPO_NAME="SharpCaster"
RELEASES_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases"
FORMULA_PATH="Formula/sharpcaster.rb"
README_PATH="README.md"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Missing required command: $1" >&2
    echo "Please install $1 and try again." >&2
    exit 1
  fi
}

require_cmd curl
require_cmd jq

# prefer sha256sum, fallback to shasum -a 256
SHA256=""
if command -v sha256sum >/dev/null 2>&1; then
  SHA256="sha256sum"
  echo "Using sha256sum for checksum calculation"
elif command -v shasum >/dev/null 2>&1; then
  SHA256="shasum -a 256"
  echo "Using shasum for checksum calculation"
else
  echo "ERROR: Missing sha256 utility (sha256sum or shasum)" >&2
  echo "Please install either sha256sum or shasum and try again." >&2
  exit 1
fi

echo "Fetching releases from ${RELEASES_API} ..."
if ! releases_json=$(curl -fsSL "$RELEASES_API"); then
  echo "ERROR: Failed to fetch releases from GitHub API" >&2
  echo "URL: $RELEASES_API" >&2
  exit 1
fi

# pick the newest non-draft release (includes prereleases)
release=$(echo "$releases_json" | jq -r '[ .[] | select(.draft==false) ] | sort_by(.created_at) | reverse | .[0]')

if [[ -z "$release" || "$release" == "null" ]]; then
  echo "ERROR: No suitable release found" >&2
  echo "This could mean:" >&2
  echo "  - No releases exist in the repository" >&2
  echo "  - All releases are marked as drafts" >&2
  echo "  - API response was malformed" >&2
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
    echo "ERROR: Missing asset for $key in release $tag" >&2
    echo "Expected asset pattern: *${key//_/-}*.tar.gz" >&2
    echo "Available assets:" >&2
    echo "$release" | jq -r '.assets[].name' >&2
    echo "" >&2
    echo "This indicates that the release $tag doesn't contain the expected assets." >&2
    echo "Please check if the release assets follow the expected naming convention." >&2
    exit 1
  fi
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

declare -A SHAS
for key in osx_arm64 osx_x64 linux_arm64 linux_x64; do
  url="${URLS[$key]}"
  out="$tmpdir/${key}.tar.gz"
  echo "Downloading $key asset from: $url"
  if ! curl -fsSL "$url" -o "$out"; then
    echo "ERROR: Failed to download asset for $key" >&2
    echo "URL: $url" >&2
    echo "Destination: $out" >&2
    exit 1
  fi
  
  if [[ ! -f "$out" ]]; then
    echo "ERROR: Downloaded file does not exist: $out" >&2
    exit 1
  fi
  
  echo "Calculating SHA256 for $key asset..."
  if [[ "$SHA256" == "sha256sum" ]]; then
    sha=$(sha256sum "$out" | awk '{print $1}')
  else
    sha=$(shasum -a 256 "$out" | awk '{print $1}')
  fi
  
  if [[ -z "$sha" ]]; then
    echo "ERROR: Failed to calculate SHA256 for $key asset" >&2
    exit 1
  fi
  
  echo "SHA256 for $key: $sha"
  SHAS[$key]="$sha"
done

# Build new formula content
NEW_FORMULA=$(cat <<'RUBY'
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
)

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
  if ! printf "%s\n" "$NEW_FORMULA" > "$FORMULA_PATH"; then
    echo "ERROR: Failed to write updated formula to $FORMULA_PATH" >&2
    exit 1
  fi
  echo "Formula updated successfully to version $version"
  changed=1
else
  echo "Formula already up to date (version $version)."
  changed=0
fi

# Update README version line
if [[ -f "$README_PATH" ]]; then
  echo "Updating README version information..."
  if grep -qE '^- \*\*Version\*\*: ' "$README_PATH"; then
    if sed -i.bak -E "s/^(- \*\*Version\*\*: ).*$/\\1$version_no_v/" "$README_PATH"; then
      rm -f "$README_PATH.bak"
      echo "README updated with version $version_no_v"
    else
      echo "ERROR: Failed to update README version" >&2
      exit 1
    fi
  else
    echo "WARNING: Version line not found in README.md (pattern: - **Version**: ...)"
  fi
else
  echo "WARNING: README.md not found at $README_PATH"
fi

# Commit and push if anything changed
if ! git diff --quiet; then
  echo "Changes detected, committing and pushing..."
  if ! git config user.name "github-actions[bot]"; then
    echo "ERROR: Failed to set git user.name" >&2
    exit 1
  fi
  if ! git config user.email "41898282+github-actions[bot]@users.noreply.github.com"; then
    echo "ERROR: Failed to set git user.email" >&2
    exit 1
  fi
  
  # Show what changed
  echo "Files that will be committed:"
  git diff --name-only
  echo ""
  echo "Changes:"
  git diff --unified=3
  echo ""
  
  if ! git add "$FORMULA_PATH" "$README_PATH" 2>/dev/null; then
    echo "WARNING: Some files could not be added to git (this may be expected if they don't exist)"
  fi
  
  if ! git commit -m "chore: update sharpcaster formula to ${version} (${tag})"; then
    echo "ERROR: Failed to commit changes" >&2
    exit 1
  fi
  
  if ! git push; then
    echo "ERROR: Failed to push changes to repository" >&2
    echo "This might be due to permission issues or network problems." >&2
    exit 1
  fi
  
  echo "Successfully committed and pushed changes for version $version"
else
  echo "No changes to commit."
fi

echo "Done."
