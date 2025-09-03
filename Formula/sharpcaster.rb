class Sharpcaster < Formula
  desc "Cross-platform C# console application for interacting with Google Chromecast devices"
  homepage "https://github.com/Tapanila/SharpCaster"
  version "3.0.0"
  revision 1
  license "MIT"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0/SharpCaster-Console-osx-arm64.tar.gz"
    sha256 "ab02e2b8e11df9a0c79982aac4e597590a47a091d6af12989f159d411a49a3e4"
  elsif OS.mac? && Hardware::CPU.intel?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0/SharpCaster-Console-osx-x64.tar.gz"
    sha256 "de86e971c99bb34fc35b3b6637d67d9b2b7aaf11acf4be4dead1eb9669bcb827"
  elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0/SharpCaster-Console-linux-arm64.tar.gz"
    sha256 "cdbc5e06a17163dd906ad73d6571fb6e7eb4b2d94c324e54d4cc7503c95c6368"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/Tapanila/SharpCaster/releases/download/3.0.0/SharpCaster-Console-linux-x64.tar.gz"
    sha256 "2b42027f0625177e5755662734912b97c89555f5ad4b219ed738883863b45ce8"
  end

  def install
    libexec.install Dir["*"]
    # Ensure the binary is executable; release archives may lack +x bit
    chmod "+x", libexec/"sharpcaster"
    bin.install_symlink libexec/"sharpcaster" => "sharpcaster"
  end

  test do
    system "#{bin}/sharpcaster", "--version"
  end
end
