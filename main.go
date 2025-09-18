package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

const (
	defaultInterval = 30 * time.Second
)

var (
	Version     = "dev"
	BuildTime   = "unknown"
	Environment = "dev"
)

func main() {
	fmt.Println("Keep-Alive Tool")
	fmt.Println("===============")
	fmt.Printf("Version: %s\n", Version)
	fmt.Printf("Build: %s (%s)\n", BuildTime, Environment)
	fmt.Printf("Platform: %s/%s\n", runtime.GOOS, runtime.GOARCH)
	fmt.Printf("Simulating user activity every %v to prevent screen lock\n", defaultInterval)
	fmt.Println("Press Ctrl+C to stop, or type 'q' and press Enter to quit")
	fmt.Println()

	// Check if running on supported OS and show platform-specific info
	switch runtime.GOOS {
	case "darwin":
		fmt.Println("macOS detected - Using cliclick for mouse simulation")
		fmt.Println("Note: If mouse movement fails, install cliclick: brew install cliclick")
	case "windows":
		fmt.Println("Windows detected - Using PowerShell with Windows API")
	default:
		fmt.Printf("Error: This tool supports macOS and Windows only (detected: %s)\n", runtime.GOOS)
		os.Exit(1)
	}
	fmt.Println()

	// Create channel to listen for interrupt signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Create channel for keyboard input
	keyboardChan := make(chan struct{}, 1)
	go _monitorKeyboard(keyboardChan)

	// Create ticker for periodic activity
	ticker := time.NewTicker(defaultInterval)
	defer ticker.Stop()

	fmt.Println("Starting keep-alive simulation...")

	for {
		select {
		case <-sigChan:
			fmt.Println("\nShutdown signal received. Stopping keep-alive tool...")
			return
		case <-keyboardChan:
			fmt.Println("\nKeyboard quit received. Stopping keep-alive tool...")
			return
		case <-ticker.C:
			_simulateActivity()
		}
	}
}

func _simulateActivity() {
	var cmd *exec.Cmd
	var err error

	switch runtime.GOOS {
	case "darwin":
		// macOS: Try cliclick first (most reliable), fallback to AppleScript
		// Check if cliclick is available
		if _, err := exec.LookPath("cliclick"); err == nil {
			// Use cliclick - more reliable and doesn't require accessibility permissions
			cmd = exec.Command("cliclick", "m:+1,+1", "w:10", "m:-1,-1")
		} else {
			// Fallback to AppleScript (requires accessibility permissions)
			script := `
				tell application "System Events"
					set currentPos to (get position of mouse)
					set mouseX to item 1 of currentPos
					set mouseY to item 2 of currentPos
					set mouse position to {mouseX + 1, mouseY + 1}
					delay 0.01
					set mouse position to {mouseX, mouseY}
				end tell
			`
			cmd = exec.Command("osascript", "-e", script)
		}

	case "windows":
		// Windows: Use PowerShell with Windows API
		script := `
			Add-Type -TypeDefinition '
				using System;
				using System.Runtime.InteropServices;
				public class Win32 {
					[DllImport("user32.dll")]
					public static extern bool GetCursorPos(out POINT lpPoint);
					[DllImport("user32.dll")]
					public static extern bool SetCursorPos(int x, int y);
					public struct POINT { public int x; public int y; }
				}
			';
			$pos = New-Object Win32+POINT;
			[Win32]::GetCursorPos([ref]$pos);
			[Win32]::SetCursorPos($pos.x + 1, $pos.y + 1);
			Start-Sleep -Milliseconds 10;
			[Win32]::SetCursorPos($pos.x, $pos.y);
		`
		cmd = exec.Command("powershell", "-Command", script)

	default:
		fmt.Printf("[%s] Error: Unsupported operating system: %s\n", time.Now().Format("15:04:05"), runtime.GOOS)
		return
	}

	err = cmd.Run()

	if err != nil {
		timestamp := time.Now().Format("15:04:05")
		if runtime.GOOS == "darwin" {
			fmt.Printf("[%s] Warning: Failed to simulate mouse activity: %v\n", timestamp, err)
			fmt.Printf("[%s] Troubleshooting: Try 'brew install cliclick' or grant accessibility permissions\n", timestamp)
		} else {
			fmt.Printf("[%s] Warning: Failed to simulate mouse activity: %v\n", timestamp, err)
		}
	} else {
		fmt.Printf("[%s] Simulated mouse activity\n", time.Now().Format("15:04:05"))
	}
}

// _monitorKeyboard monitors for 'q' input to quit the program
func _monitorKeyboard(keyboardChan chan struct{}) {
	for {
		var input string
		// Read line from stdin
		if _, err := fmt.Scanln(&input); err != nil {
			// If stdin is closed or there's an error, continue
			continue
		}
		
		// Check for quit commands
		if input == "q" || input == "quit" || input == "exit" {
			keyboardChan <- struct{}{}
			return
		}
	}
}
