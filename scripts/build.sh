#!/bin/bash
# -----------------------------------------------------------------------
# Build Script for Keep-Alive Tool (macOS)
# -----------------------------------------------------------------------

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
VERSION=""
CLEAN=false
TEST=false
VERBOSE=false
RELEASE=false
ARCH=""

# Help function
show_help() {
    cat << EOF
Build Script for Keep-Alive Tool (macOS)

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV   Target environment (dev, staging, prod) [default: dev]
    -v, --version VERSION   Version to embed in binary
    -c, --clean            Clean build artifacts before building
    -t, --test             Run tests before building
    -r, --release          Build optimized release binary
    -a, --arch ARCH        Target architecture (amd64, arm64, auto) [default: auto]
    --verbose              Enable verbose output
    -h, --help             Show this help message

EXAMPLES:
    $0                                    # Build for current architecture (dev)
    $0 --release --test                   # Build optimized release with tests
    $0 --arch arm64 --release             # Build for Apple Silicon (M1/M2)
    $0 --arch amd64 --release             # Build for Intel Macs
    $0 --environment prod --version 1.0.0 # Build production binary with specific version

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--test)
            TEST=true
            shift
            ;;
        -r|--release)
            RELEASE=true
            shift
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Change to project root directory
cd "$(dirname "$(dirname "$0")")"

echo -e "${CYAN}Keep-Alive Tool Build Script (macOS)${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo "Current Location: $(pwd)"

# Validate environment
case $ENVIRONMENT in
    dev|staging|prod)
        ;;
    *)
        echo -e "${RED}Error: Invalid environment: $ENVIRONMENT. Valid options: dev, staging, prod${NC}"
        exit 1
        ;;
esac

# Detect architecture if not specified
if [[ "$ARCH" == "" || "$ARCH" == "auto" ]]; then
    SYSTEM_ARCH=$(uname -m)
    case $SYSTEM_ARCH in
        x86_64)
            ARCH="amd64"
            echo -e "${GREEN}Detected Intel Mac (x86_64) -> Building for amd64${NC}"
            ;;
        arm64)
            ARCH="arm64"
            echo -e "${GREEN}Detected Apple Silicon Mac (arm64) -> Building for arm64${NC}"
            ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $SYSTEM_ARCH${NC}"
            exit 1
            ;;
    esac
else
    case $ARCH in
        amd64|arm64)
            echo -e "${GREEN}Building for specified architecture: $ARCH${NC}"
            ;;
        *)
            echo -e "${RED}Error: Invalid architecture: $ARCH. Valid options: amd64, arm64, auto${NC}"
            exit 1
            ;;
    esac
fi

# Get version information
if [[ -z "$VERSION" ]]; then
    # Try to read from .version file first
    if [[ -f ".version" ]]; then
        VERSION=$(grep '^version:' .version | awk '{print $2}' | tr -d ' ')
    fi

    # Fall back to git if .version file doesn't exist or version not found
    if [[ -z "$VERSION" ]]; then
        if command -v git >/dev/null 2>&1; then
            VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")
        else
            VERSION="dev"
        fi
    fi
fi

echo -e "${GREEN}Version: $VERSION${NC}"

# Get build timestamp
BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "Build Time: $BUILD_TIME"

# Clean if requested
if [[ "$CLEAN" == true ]]; then
    echo -e "\n${YELLOW}Cleaning build artifacts...${NC}"
    [[ -d "bin" ]] && rm -rf bin
    go clean -cache
    echo -e "${GREEN}Clean complete${NC}"
fi

# Run tests if requested
if [[ "$TEST" == true ]]; then
    echo -e "\n${YELLOW}Running tests...${NC}"
    if [[ "$VERBOSE" == true ]]; then
        go test -v ./...
    else
        go test ./...
    fi
    echo -e "${GREEN}Tests passed${NC}"
fi

# Create bin directory if it doesn't exist
mkdir -p bin

# Determine output binary name
if [[ "$ARCH" == "amd64" ]]; then
    OUTPUT_NAME="keep-alive-darwin-amd64"
elif [[ "$ARCH" == "arm64" ]]; then
    OUTPUT_NAME="keep-alive-darwin-arm64"
fi
OUTPUT_PATH="bin/$OUTPUT_NAME"

# Set up build environment for macOS
export CGO_ENABLED=0
export GOOS=darwin
export GOARCH=$ARCH

# Build arguments
BUILD_ARGS=(
    "build"
    "-o" "$OUTPUT_PATH"
)

# Add ldflags for version information
LDFLAGS=(
    "-X 'main.Version=$VERSION'"
    "-X 'main.BuildTime=$BUILD_TIME'"
    "-X 'main.Environment=$ENVIRONMENT'"
)

if [[ "$RELEASE" == true ]]; then
    echo -e "\n${YELLOW}Building release binary...${NC}"
    LDFLAGS+=("-s" "-w")
    BUILD_ARGS+=("-trimpath")
else
    echo -e "\n${YELLOW}Building development binary...${NC}"
fi

BUILD_ARGS+=("-ldflags" "$(IFS=' '; echo "${LDFLAGS[*]}")")

if [[ "$VERBOSE" == true ]]; then
    BUILD_ARGS+=("-v")
fi

# Add source path
BUILD_ARGS+=(".")

# Show build command if verbose
if [[ "$VERBOSE" == true ]]; then
    echo -e "${CYAN}Build command: go ${BUILD_ARGS[*]}${NC}"
fi

# Execute build
if ! go "${BUILD_ARGS[@]}"; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

# Make binary executable
chmod +x "$OUTPUT_PATH"

# Display build results
echo -e "\n${GREEN}Build successful!${NC}"
echo -e "${YELLOW}Output: $OUTPUT_PATH${NC}"

# Show binary info
if [[ -f "$OUTPUT_PATH" ]]; then
    SIZE=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || echo "unknown")
    if [[ "$SIZE" != "unknown" ]]; then
        SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc 2>/dev/null || echo "unknown")
        echo "Size: ${SIZE_MB} MB"
    fi
fi

echo "Target: darwin/$ARCH"
echo -e "${GREEN}Binary is ready to run: ./$OUTPUT_PATH${NC}"

echo -e "\n${GREEN}Build complete!${NC}"