# Homebrew SharpCaster

A Homebrew tap for [SharpCaster](https://github.com/Tapanila/SharpCaster), a cross-platform C# console application for interacting with Google Chromecast devices.

## Installation

```bash
# Add the tap
brew tap Tapanila/sharpcaster

# Install SharpCaster
brew install sharpcaster
```

## Usage

After installation, you can run SharpCaster from the command line:

```bash
sharpcaster --help
```

## About SharpCaster

SharpCaster is a cross-platform C# SDK and console application for interacting with Google Chromecast devices. It provides:

- Device discovery via mDNS
- Media playback control  
- Media queue management
- Application launching
- Volume control
- Event-driven architecture

## Formula Details

- **Version**: 3.0.0-beta1
- **License**: MIT
- **Supported platforms**: macOS (Intel and Apple Silicon), Linux (64 and ARM)
- **Homepage**: https://github.com/Tapanila/SharpCaster

## Contributing

This tap follows the standard Homebrew tap structure. The formula is located in `Formula/sharpcaster.rb`.

## License

This tap is released under the same MIT license as the SharpCaster project.