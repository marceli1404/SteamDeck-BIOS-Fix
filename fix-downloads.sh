#!/bin/bash

# SteamDeck-BIOS-Manager Download Fix
# Fixes MD5 hash check failures caused by silent curl failures
# https://github.com/marceli1404/SteamDeck-BIOS-Fix

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "========================================"
echo " SteamDeck BIOS Manager - Download Fix"
echo "========================================"
echo ""

# --- 1. Check disk space ---
echo "[1/5] Checking disk space..."
AVAIL=$(df -BM ~ | awk 'NR==2 {print $4}' | tr -d 'M')
if [ "$AVAIL" -lt 500 ]; then
    error "Only ${AVAIL}MB free. Need at least 500MB for BIOS files."
    exit 1
fi
info "${AVAIL}MB available (OK)"

# --- 2. Check SSL certificates ---
echo ""
echo "[2/5] Checking SSL certificates..."
if ! curl -sI https://gitlab.com > /dev/null 2>&1; then
    warn "SSL connection to gitlab.com failed. Attempting fix..."
    if command -v sudo &> /dev/null; then
        sudo steamos-readonly disable 2>/dev/null
        sudo pacman -S --noconfirm ca-certificates 2>/dev/null
        sudo steamos-readonly enable 2>/dev/null
        if curl -sI https://gitlab.com > /dev/null 2>&1; then
            info "SSL certificates updated successfully"
        else
            error "SSL still failing after cert update. Check network connection."
            exit 1
        fi
    else
        error "Cannot fix SSL without sudo. Check network connection."
        exit 1
    fi
else
    info "SSL to gitlab.com OK"
fi

if ! curl -sI https://www.deckhd.com > /dev/null 2>&1; then
    warn "SSL connection to deckhd.com failed (non-critical, DeckHD BIOS will be skipped)"
else
    info "SSL to deckhd.com OK"
fi

if ! curl -sI https://balika011.hu > /dev/null 2>&1; then
    warn "SSL connection to balika011.hu failed (non-critical, 32GB BIOS will be skipped)"
else
    info "SSL to balika011.hu OK"
fi

# --- 3. Create BIOS directory ---
echo ""
echo "[3/5] Preparing BIOS directory..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIOS_DIR="${SCRIPT_DIR}/BIOS"
mkdir -p "$BIOS_DIR"
# Clean old files
rm -f "${BIOS_DIR}"/F*.fd 2>/dev/null
info "BIOS directory ready: ${BIOS_DIR}"

# --- 4. Download with retry ---
echo ""
echo "[4/5] Downloading BIOS files..."

MODEL=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "Unknown")
if [ "$MODEL" = "Jupiter" ]; then
    PLATFORM="LCD"
elif [ "$MODEL" = "Galileo" ]; then
    PLATFORM="OLED"
else
    warn "Could not detect Steam Deck model (got: $MODEL). Defaulting to LCD."
    PLATFORM="LCD"
fi
info "Detected model: $PLATFORM ($MODEL)"

download_with_retry() {
    local url="$1"
    local dest="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -sL --fail --connect-timeout 15 --max-time 120 -o "$dest" "$url" 2>/dev/null; then
            # Verify file is not empty
            if [ -s "$dest" ]; then
                return 0
            fi
            warn "Downloaded file is empty, retrying..."
        fi
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            warn "Download failed (attempt $retry/$max_retries), retrying in 2s..."
            sleep 2
        fi
    done
    return 1
}

download_bios() {
    local name="$1"
    local url="$2"
    printf "  %-45s" "$name"
    if download_with_retry "$url" "${BIOS_DIR}/${name}"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        rm -f "${BIOS_DIR}/${name}" 2>/dev/null
    fi
}

if [ "$PLATFORM" = "LCD" ]; then
    download_bios "F7A0110_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/0660b2a5a9df3bd97751fe79c55859e3b77aec7d/usr/share/jupiter_bios/F7A0110_sign.fd"
    download_bios "F7A0113_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/bf77354719c7a74097a23bed4fb889df4045aec4/usr/share/jupiter_bios/F7A0113_sign.fd"
    download_bios "F7A0115_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/5644a5692db16b429b09e48e278b484a2d1d4602/usr/share/jupiter_bios/F7A0115_sign.fd"
    download_bios "F7A0116_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/38f7bdc2676421ee11104926609b4cc7a4dbc6a3/usr/share/jupiter_bios/F7A0116_sign.fd"
    download_bios "F7A0118_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/f79ccd15f68e915cc02537854c3b37f1a04be9c3/usr/share/jupiter_bios/F7A0118_sign.fd"
    download_bios "F7A0119_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/bc5ca4c3fc739d09e766a623efd3d98fac308b3e/usr/share/jupiter_bios/F7A0119_sign.fd"
    download_bios "F7A0120_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/a43e38819ba20f363bdb5bedcf3f15b75bf79323/usr/share/jupiter_bios/F7A0120_sign.fd"
    download_bios "F7A0121_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/7ffc22a4dc083c005e26676d276bdbd90dd1de5e/usr/share/jupiter_bios/F7A0121_sign.fd"
    download_bios "F7A0131_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/eb91bebf4c2e5229db071720250d80286368e4e2/usr/share/jupiter_bios/F7A0131_sign.fd"
    download_bios "F7A0133_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/5c14655a762870754f9d8574682b6727cb640904/usr/share/jupiter_bios/F7A0133_sign.fd"
elif [ "$PLATFORM" = "OLED" ]; then
    download_bios "F7G0107_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/a43e38819ba20f363bdb5bedcf3f15b75bf79323/usr/share/jupiter_bios/F7G0107_sign.fd"
    download_bios "F7G0109_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/7ffc22a4dc083c005e26676d276bdbd90dd1de5e/usr/share/jupiter_bios/F7G0109_sign.fd"
    download_bios "F7G0110_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/eb91bebf4c2e5229db071720250d80286368e4e2/usr/share/jupiter_bios/F7G0110_sign.fd"
    download_bios "F7G0112_sign.fd" "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/6101a30a621a2119e8c5213e872b268973659964/usr/share/jupiter_bios/F7G0112_sign.fd"
fi

# --- 5. Verify MD5 hashes ---
echo ""
echo "[5/5] Verifying MD5 hashes..."

MD5_FILE="${SCRIPT_DIR}/md5.txt"
if [ ! -f "$MD5_FILE" ]; then
    warn "md5.txt not found, skipping verification"
    warn "Copy md5.txt from https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager/blob/main/md5.txt"
    exit 0
fi

PASS=0
FAIL=0
for BIOS_FD in "${BIOS_DIR}"/*.fd; do
    [ -f "$BIOS_FD" ] || continue
    FILENAME=$(basename "$BIOS_FD")
    ACTUAL_MD5=$(md5sum "$BIOS_FD" | cut -d " " -f 1)
    EXPECTED_MD5=$(grep "$FILENAME" "$MD5_FILE" | cut -d " " -f 1)

    if [ -z "$EXPECTED_MD5" ]; then
        warn "$FILENAME - no MD5 in md5.txt (skipped)"
    elif [ "$ACTUAL_MD5" = "$EXPECTED_MD5" ]; then
        info "$FILENAME - MD5 OK"
        PASS=$((PASS + 1))
    else
        error "$FILENAME - MD5 MISMATCH (expected: $EXPECTED_MD5, got: $ACTUAL_MD5)"
        rm -f "$BIOS_FD"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================"

if [ $FAIL -eq 0 ] && [ $PASS -gt 0 ]; then
    echo ""
    info "All BIOS files downloaded and verified!"
    info "You can now use the original SteamDeck-BIOS-Manager script to flash."
elif [ $FAIL -gt 0 ]; then
    echo ""
    error "$FAIL file(s) had MD5 mismatches and were deleted."
    error "Run this script again to retry, or check your network connection."
    exit 1
else
    warn "No BIOS files were downloaded."
    error "Check your network connection and try again."
    exit 1
fi
