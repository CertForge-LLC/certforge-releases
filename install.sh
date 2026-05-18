#!/bin/sh
# CertForge installer
# Usage: curl -fsSL https://raw.githubusercontent.com/CertForge-LLC/certforge/main/install.sh | sh
#    or: sh install.sh [version]          e.g. sh install.sh v1.2.3
#    or: sh install.sh [version] [dir]    e.g. sh install.sh latest /usr/local/bin
set -e

REPO="CertForge-LLC/certforge-releases"
BINARY="certforge"
INSTALL_DIR="${2:-/usr/local/bin}"

# ── detect OS ─────────────────────────────────────────────────────────────────
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux)   OS="linux"   ;;
  darwin)  OS="darwin"  ;;
  mingw*|msys*|cygwin*) OS="windows" ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

# ── detect arch ───────────────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)    ARCH="amd64"  ;;
  aarch64|arm64)   ARCH="arm64"  ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# ── resolve version ───────────────────────────────────────────────────────────
VERSION="${1:-latest}"
if [ "$VERSION" = "latest" ]; then
  echo "Fetching latest CertForge version..."
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" \
      | grep '"tag_name"' | head -1 \
      | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  fi
  if [ -z "$VERSION" ]; then
    echo "Could not determine latest version. Specify a version: sh install.sh v1.0.0" >&2
    exit 1
  fi
  echo "Latest version: $VERSION"
fi

VER_NUM="${VERSION#v}"

# ── build download URL ────────────────────────────────────────────────────────
EXT="tar.gz"
[ "$OS" = "windows" ] && EXT="zip"
FILENAME="${BINARY}_${VER_NUM}_${OS}_${ARCH}.${EXT}"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${FILENAME}"

# ── download ──────────────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading CertForge ${VERSION} for ${OS}/${ARCH}..."
curl -fsSL "$URL" -o "${TMP}/${FILENAME}"

# ── extract ───────────────────────────────────────────────────────────────────
if [ "$EXT" = "tar.gz" ]; then
  tar -xzf "${TMP}/${FILENAME}" -C "$TMP"
else
  unzip -q "${TMP}/${FILENAME}" -d "$TMP"
fi

# ── install ───────────────────────────────────────────────────────────────────
BIN_NAME="$BINARY"
[ "$OS" = "windows" ] && BIN_NAME="${BINARY}.exe"
BIN_SRC=$(find "$TMP" -maxdepth 2 -name "$BIN_NAME" -type f | head -1)

if [ -z "$BIN_SRC" ]; then
  echo "Binary not found in archive" >&2; exit 1
fi

if [ -w "$INSTALL_DIR" ]; then
  cp "$BIN_SRC" "${INSTALL_DIR}/${BINARY}"
  chmod +x "${INSTALL_DIR}/${BINARY}"
else
  echo "Installing to ${INSTALL_DIR} (may prompt for password)..."
  sudo cp "$BIN_SRC" "${INSTALL_DIR}/${BINARY}"
  sudo chmod +x "${INSTALL_DIR}/${BINARY}"
fi

# ── install config (first-time only) ─────────────────────────────────────────
CONFIG_DIR="/etc/certforge"
CONFIG_FILE="${CONFIG_DIR}/trust.yaml"
EXAMPLE_SRC=$(find "$TMP" -maxdepth 2 -name "trust.example.yaml" | head -1)

if [ -n "$EXAMPLE_SRC" ] && [ ! -f "$CONFIG_FILE" ]; then
  CURRENT_USER=$(id -un)
  if [ -w "/etc" ]; then
    mkdir -p "$CONFIG_DIR"
    sed 's|base_path: ./data|base_path: /var/lib/certforge|' "$EXAMPLE_SRC" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    mkdir -p /var/lib/certforge
    chown "$CURRENT_USER" /var/lib/certforge
  else
    sudo mkdir -p "$CONFIG_DIR"
    sudo sh -c "sed 's|base_path: ./data|base_path: /var/lib/certforge|' \"$EXAMPLE_SRC\" > \"$CONFIG_FILE\""
    sudo chown "$CURRENT_USER" "$CONFIG_FILE"
    sudo chmod 600 "$CONFIG_FILE"
    sudo mkdir -p /var/lib/certforge
    sudo chown "$CURRENT_USER" /var/lib/certforge
  fi
  echo "Config installed to ${CONFIG_FILE}"
fi

echo ""
echo "CertForge ${VERSION} installed to ${INSTALL_DIR}/${BINARY}"
echo ""
echo "Next steps:"
echo "  1. Get a trial license at https://certforge.xyz"
echo "     (license.jwt will be emailed — place it in /var/lib/certforge/)"
echo "  2. Edit ${CONFIG_FILE} if needed"
echo "  3. Run: certforge"
echo "  4. Open http://localhost:8080 in your browser"
echo ""
echo "Documentation: https://github.com/CertForge-LLC/certforge-releases"
