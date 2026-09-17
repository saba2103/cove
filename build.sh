#!/bin/bash
set -e

echo "==> Preparing build environment for Flutter Web..."

# If flutter is not installed in the container, install it
if ! command -v flutter &> /dev/null; then
  if [ ! -d "$HOME/flutter" ] && [ ! -d "flutter" ]; then
    echo "==> Cloning Flutter SDK (stable branch)..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  fi
  if [ -d "$HOME/flutter/bin" ]; then
    export PATH="$PATH:$HOME/flutter/bin"
  elif [ -d "flutter/bin" ]; then
    export PATH="$PATH:$(pwd)/flutter/bin"
  fi
fi

echo "==> Verifying Flutter installation..."
flutter --version

echo "==> Enabling web support..."
flutter config --enable-web

echo "==> Resolving dependencies..."
flutter pub get

echo "==> Building Flutter Web (release mode)..."
flutter build web --release

echo "==> Build complete! Output available in build/web"
