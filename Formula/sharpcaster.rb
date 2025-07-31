class Sharpcaster < Formula
  desc "Cross-platform C# console application for interacting with Google Chromecast devices"
  homepage "https://github.com/Tapanila/SharpCaster"
  version "3.0.0-beta1"
  license "MIT"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0-beta1/SharpCaster-Console-osx-arm64-12.66MB.zip"
    sha256 "ba24f65e18080c32a07afe55310532d4c66c0a581684242bb2763f8d4a7815f7"
  elsif OS.mac? && Hardware::CPU.intel?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0-beta1/SharpCaster-Console-osx-x64-12.5MB.zip"
    sha256 "9b15f591376d48fdfc3a043366f250dbbdda261a39e20cd4eab626d10dcd203d"
  elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0-beta1/SharpCaster-Console-linux-arm64-14.74MB.zip"
    sha256 "7f4978dc095d59d5c06180d85e4946b4b8e1da22b1982206c58d7ba25adb9864"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0-beta1/SharpCaster-Console-linux-x64-14.19MB.zip"
    sha256 "4aff567a5c5b7c07d33cf520674071fa0554632a1d3c94b9d74acc8f08f627a3"
  end

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"sharpcaster" => "sharpcaster"
  end

  test do
    system "#{bin}/sharpcaster", "--version"
  end
end