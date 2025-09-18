# -----------------------------------------------------------------------
# Build Script for Keep-Alive Tool
# -----------------------------------------------------------------------

param (
    [string]$Environment = "dev",
    [string]$Version = "",
    [switch]$Clean,
    [switch]$Test,
    [switch]$Verbose,
    [switch]$Release,
    [string]$Arch = "amd64"
)

<#
.SYNOPSIS
    Build script for Keep-Alive Tool

.DESCRIPTION
    This script builds the Keep-Alive Tool binary for local development and deployment.
    Outputs the executable to the project's bin directory.

.PARAMETER Environment
    Target environment for build (dev, staging, prod)

.PARAMETER Version
    Version to embed in the binary (defaults to .version file or git commit hash)

.PARAMETER Clean
    Clean build artifacts before building

.PARAMETER Test
    Run tests before building

.PARAMETER Verbose
    Enable verbose output

.PARAMETER Release
    Build optimized release binary

.PARAMETER Arch
    Target architecture (amd64, arm64) - defaults to amd64

.EXAMPLE
    .\build.ps1
    Build keep-alive-tool for Windows development (amd64)

.EXAMPLE
    .\build.ps1 -Environment prod -Release -Test
    Build optimized production binary with tests

.EXAMPLE
    .\build.ps1 -Arch arm64 -Release
    Build for Windows ARM64
#>

Push-Location (Split-Path (Split-Path $MyInvocation.MyCommand.Path))

try {
    Write-Host "Keep-Alive Tool Build Script" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Yellow
    Write-Host "Current Location: $(Get-Location)"

    # Validate environment
    $validEnvironments = @("dev", "staging", "prod")
    if ($Environment -notin $validEnvironments) {
        Write-Error "Invalid environment: $Environment. Valid options: $($validEnvironments -join ', ')"
        exit 1
    }

    # Get version information
    if (-not $Version) {
        # Try to read from .version file first
        $versionFilePath = ".version"
        if (Test-Path $versionFilePath) {
            $versionLines = Get-Content $versionFilePath
            foreach ($line in $versionLines) {
                if ($line -match '^version:\s*(.+)$') {
                    $Version = $matches[1].Trim()
                    break
                }
            }
        }

        # Fall back to git if .version file doesn't exist or version not found
        if (-not $Version) {
            try {
                $Version = git rev-parse --short HEAD 2>$null
                if (-not $Version) {
                    $Version = "dev"
                }
            }
            catch {
                $Version = "dev"
            }
        }
    }

    Write-Host "Version: $Version" -ForegroundColor Green

    # Get build timestamp
    $buildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Build Time: $buildTime"

    # Clean if requested
    if ($Clean) {
        Write-Host "`nCleaning build artifacts..." -ForegroundColor Yellow
        if (Test-Path "bin") {
            Remove-Item -Path "bin" -Recurse -Force
        }
        go clean -cache
        Write-Host "Clean complete" -ForegroundColor Green
    }

    # Run tests if requested
    if ($Test) {
        Write-Host "`nRunning tests..." -ForegroundColor Yellow
        $testArgs = @("test", "./...")
        if ($Verbose) {
            $testArgs += "-v"
        }
        $testResult = & go @testArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Tests failed"
            exit 1
        }
        Write-Host "Tests passed" -ForegroundColor Green
    }

    # Create bin directory if it doesn't exist
    $binDir = Join-Path -Path (Get-Location) -ChildPath "bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir | Out-Null
    }

    # Determine output binary name for Windows with architecture
    if ($Arch -eq "amd64") {
        $outputName = "keep-alive.exe"
    } else {
        $outputName = "keep-alive-windows-$Arch.exe"
    }
    $outputPath = Join-Path -Path $binDir -ChildPath $outputName

    # Set up build environment for Windows
    $env:CGO_ENABLED = "0"
    $env:GOOS = "windows"
    $env:GOARCH = $Arch

    # Build arguments
    $buildArgs = @(
        "build",
        "-o", $outputPath
    )

    # Add ldflags for version information
    $ldflags = @(
        "-X 'main.Version=$Version'",
        "-X 'main.BuildTime=$buildTime'",
        "-X 'main.Environment=$Environment'"
    )

    if ($Release) {
        Write-Host "`nBuilding release binary..." -ForegroundColor Yellow
        $ldflags += @("-s", "-w")
        $buildArgs += "-trimpath"
    }
    else {
        Write-Host "`nBuilding development binary..." -ForegroundColor Yellow
    }

    $buildArgs += "-ldflags", ($ldflags -join " ")

    if ($Verbose) {
        $buildArgs += "-v"
    }

    # Add source path (main.go is in root)
    $buildArgs += "."

    # Show build command if verbose
    if ($Verbose) {
        Write-Host "Build command: go $($buildArgs -join ' ')" -ForegroundColor DarkGray
    }

    # Execute build
    $buildResult = & go @buildArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed: $buildResult"
        exit 1
    }

    # Display build results
    Write-Host "`nBuild successful!" -ForegroundColor Green
    Write-Host "Output: $outputPath" -ForegroundColor Yellow

    # Show binary info
    $fileInfo = Get-Item $outputPath
    Write-Host "Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"

    Write-Host "Target: windows/$Arch"

    Write-Host "`nBuild complete!" -ForegroundColor Green
}
catch {
    Write-Error "Build failed: $_"
    exit 1
}
finally {
    Pop-Location
}