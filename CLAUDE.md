# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Keep-Alive Tool is a cross-platform Go application that prevents screen lock by simulating minimal mouse movement every 30 seconds. The tool supports macOS and Windows through platform-specific implementations using AppleScript and PowerShell respectively.

## Architecture

### Core Design
- **Single Binary**: The entire application is contained in `main.go` with no external dependencies
- **Cross-Platform**: Runtime detection determines execution path (`runtime.GOOS`)
- **Signal Handling**: Graceful shutdown using Go's signal package
- **Timer-Based**: Uses `time.Ticker` for 30-second intervals

### Platform Implementations
- **macOS**: Uses `osascript` to execute AppleScript for mouse manipulation
- **Windows**: Uses `powershell` with Windows API calls (`user32.dll`) for cursor control
- **Movement Pattern**: Moves cursor 1 pixel diagonally, then returns to original position

## Development Commands

### Building

#### Windows (PowerShell)
```powershell
# Development build (default amd64)
.\scripts\build.ps1

# Release build with tests
.\scripts\build.ps1 -Release -Test

# Build for ARM64
.\scripts\build.ps1 -Arch arm64 -Release

# Clean build with verbose output
.\scripts\build.ps1 -Clean -Verbose -Environment prod
```

#### macOS (Bash)
```bash
# Development build (auto-detects architecture)
./scripts/build.sh

# Release build with tests
./scripts/build.sh --release --test

# Build for specific architecture
./scripts/build.sh --arch arm64 --release  # Apple Silicon
./scripts/build.sh --arch amd64 --release  # Intel Mac

# Clean build with verbose output
./scripts/build.sh --clean --verbose --environment prod
```

### Testing
```bash
# Run all tests
go test ./...

# Run tests with verbose output
go test -v ./...
```

### Direct Go Commands
```bash
# Simple build
go build .

# Build with version info
go build -ldflags "-X 'main.Version=1.0.0' -X 'main.BuildTime=$(date)' -X 'main.Environment=dev'" .

# Format code
go fmt ./...

# Download dependencies
go mod download
```

## Build System

### Version Management
- Version can be specified via `-Version` parameter
- Falls back to `.version` file (format: `version: x.x.x`)
- Ultimate fallback to git commit hash (`git rev-parse --short HEAD`)

### Build Outputs
- Binaries are output to `bin/` directory
- Default Windows output: `bin/keep-alive.exe`
- ARM64 output: `bin/keep-alive-windows-arm64.exe`

### Build Variables
The following variables are injected at build time:
- `main.Version`: Version string
- `main.BuildTime`: Build timestamp
- `main.Environment`: Target environment (dev/staging/prod)

## Code Structure

### Key Functions
- `main()`: Entry point, platform validation, signal handling, timer setup
- `_simulateActivity()`: Platform-specific mouse movement implementation (private function with underscore prefix)

### Platform Detection
Uses `runtime.GOOS` to determine execution path. Exits with error code 1 on unsupported platforms.

### Error Handling
- Graceful degradation: Warns on simulation failures but continues running
- Validates OS support at startup
- Non-zero exit codes for build/runtime errors