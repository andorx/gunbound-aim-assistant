#!/bin/bash

# Build script for Gunbound Aim Assistant (Swift version)

set -e  # Exit on error

echo "🔨 Building Gunbound Aim Assistant (Swift)..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
swift package clean

# Build the project
echo "📦 Building project..."
swift build

echo ""
echo "✅ Build successful!"
echo ""
echo "To run the application:"
echo "  swift run"
echo ""
echo "Or run the executable directly:"
echo "  .build/debug/GunboundAimAssistant"
echo ""
echo "For release build:"
echo "  swift build -c release"
echo "  .build/release/GunboundAimAssistant"
