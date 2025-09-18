# Keep-Alive Tool

A simple cross-platform command-line tool that prevents screen lock by simulating minimal user activity on macOS and Windows.

## Features

- Prevents screen lock by moving mouse cursor slightly every 30 seconds
- Cross-platform support (macOS and Windows)
- Non-intrusive: moves mouse by 1 pixel and returns to original position
- Does not interfere with real mouse/keyboard movements
- Dual quit methods: Ctrl+C or type 'q' and press Enter
- Enhanced macOS support with cliclick integration (no accessibility permissions needed)
- Automatic fallback to AppleScript if cliclick not installed
- Multiple architecture support (AMD64, ARM64)

## Installation

Download the appropriate binary from the [Releases](../../releases) page:

### macOS
- `keep-alive-tool-darwin-universal` - Universal binary (recommended)
- `keep-alive-tool-darwin-amd64` - Intel Macs
- `keep-alive-tool-darwin-arm64` - Apple Silicon Macs

### Windows
- `keep-alive-tool-windows-amd64.exe` - Intel/AMD 64-bit
- `keep-alive-tool-windows-arm64.exe` - ARM 64-bit

## Usage

### macOS
1. Open Terminal
2. Navigate to the directory containing the binary
3. Make it executable: `chmod +x keep-alive-tool-darwin-universal`
4. Run: `./keep-alive-tool-darwin-universal`

### Windows
1. Open Command Prompt or PowerShell
2. Navigate to the directory containing the binary
3. Run: `keep-alive-tool-windows-amd64.exe`

### Example Output
```bash
$ ./keep-alive-tool-darwin-universal
Keep-Alive Tool
===============
Version: 1.0.0
Build: 2025-09-18 11:01:17 (dev)
Platform: darwin/arm64
Simulating user activity every 30s to prevent screen lock
Press Ctrl+C to stop, or type 'q' and press Enter to quit

macOS detected - Using cliclick for mouse simulation
Note: If mouse movement fails, install cliclick: brew install cliclick

Starting keep-alive simulation...
[14:30:15] Simulated mouse activity
[14:30:45] Simulated mouse activity

# User can quit by:
# 1. Pressing Ctrl+C
^C
Shutdown signal received. Stopping keep-alive tool...

# 2. Or typing 'q' and pressing Enter
q
Keyboard quit received. Stopping keep-alive tool...
```

## Building from Source

Requirements:
- Go 1.21 or later

```bash
git clone <repository-url>
cd keep-alive-tool
go mod download
go build .
```

## How it Works

### macOS
Primary method uses `cliclick` (recommended):
1. Install cliclick: `brew install cliclick`
2. Moves mouse 1 pixel relative, waits 10ms, then moves back
3. No accessibility permissions required

Fallback method uses AppleScript via `osascript`:
1. Get the current mouse position
2. Move the mouse 1 pixel diagonally
3. Immediately return it to the original position
4. **Requires**: System Preferences → Security & Privacy → Privacy → Accessibility → Add Terminal

### Windows
Uses PowerShell with Windows API calls to:
1. Get the current cursor position via `GetCursorPos`
2. Move the cursor 1 pixel diagonally via `SetCursorPos`
3. Immediately return it to the original position

This minimal movement every 30 seconds is enough to prevent the system from considering it idle while being virtually unnoticeable to the user.

## License

MIT License