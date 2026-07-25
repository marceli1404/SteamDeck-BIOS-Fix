#!/bin/bash

# Steam Deck BIOS Manager - One-Click Fix
# Fixes black screen of death by downloading and flashing a working BIOS
# https://github.com/marceli1404/SteamDeck-BIOS-Fix

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[FAIL]${NC}  $1"; }
step()    { echo -e "\n${CYAN}==> Step $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIOS_DIR="${SCRIPT_DIR}/BIOS"

clear
echo "============================================"
echo "  Steam Deck BIOS Manager - One-Click Fix"
echo "  Fixes Black Screen of Death"
echo "============================================"
echo ""

# =====================
# STEP 1 - Prerequisites
# =====================
step "1/7 - Checking prerequisites"

# Check sudo
if [ "$(passwd --status $(whoami) 2>/dev/null | tr -s " " | cut -d " " -f 2)" != "P" ]; then
    error "Sudo password not set. Set one first: passwd"
    exit 1
fi
PASSWORD=$(zenity --password --title "sudo Password" --width 300 2>/dev/null)
echo -e "$PASSWORD\n" | sudo -S ls &> /dev/null
if [ $? -ne 0 ]; then
    error "Wrong sudo password"
    exit 1
fi
info "Sudo password OK"

# Check model
MODEL=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
BIOS_VERSION=$(cat /sys/class/dmi/id/bios_version 2>/dev/null)
if [ "$MODEL" = "Jupiter" ]; then
    PLATFORM="LCD"
elif [ "$MODEL" = "Galileo" ]; then
    PLATFORM="OLED"
else
    error "Unknown model: $MODEL"
    exit 1
fi
info "Model: $PLATFORM ($MODEL) - Current BIOS: $BIOS_VERSION"

# Check disk space
AVAIL=$(df -BM ~ | awk 'NR==2 {print $4}' | tr -d 'M')
if [ "$AVAIL" -lt 500 ]; then
    error "Only ${AVAIL}MB free. Need 500MB+"
    exit 1
fi
info "Disk space: ${AVAIL}MB available"

# =====================
# STEP 2 - SSL/Network
# =====================
step "2/7 - Checking network and SSL"

if ! curl -sI --connect-timeout 10 https://gitlab.com > /dev/null 2>&1; then
    warn "SSL to gitlab.com failed. Fixing..."
    echo -e "$PASSWORD\n" | sudo -S steamos-readonly disable 2>/dev/null
    echo -e "$PASSWORD\n" | sudo -S pacman -S --noconfirm ca-certificates 2>/dev/null
    echo -e "$PASSWORD\n" | sudo -S steamos-readonly enable 2>/dev/null
    if curl -sI --connect-timeout 10 https://gitlab.com > /dev/null 2>&1; then
        info "SSL fixed"
    else
        error "SSL still broken. Check your internet connection."
        exit 1
    fi
else
    info "Network OK"
fi

# =====================
# STEP 3 - Download BIOS
# =====================
step "3/7 - Downloading BIOS files"

mkdir -p "$BIOS_DIR"
rm -f "${BIOS_DIR}"/F*.fd 2>/dev/null

download_with_retry() {
    local url="$1"
    local dest="$2"
    local retry=0
    while [ $retry -lt 3 ]; do
        if curl -sL --fail --connect-timeout 15 --max-time 120 -o "$dest" "$url" 2>/dev/null && [ -s "$dest" ]; then
            return 0
        fi
        retry=$((retry + 1))
        [ $retry -lt 3 ] && sleep 2
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

# Count downloads
DOWNLOADED=$(ls "${BIOS_DIR}"/*.fd 2>/dev/null | wc -l)
if [ "$DOWNLOADED" -eq 0 ]; then
    error "No BIOS files downloaded. Check your network."
    exit 1
fi
info "$DOWNLOADED BIOS files downloaded"

# =====================
# STEP 4 - Verify MD5
# =====================
step "4/7 - Verifying MD5 checksums"

MD5_FILE="${SCRIPT_DIR}/md5.txt"
PASS=0
FAIL=0
for BIOS_FD in "${BIOS_DIR}"/*.fd; do
    [ -f "$BIOS_FD" ] || continue
    FILENAME=$(basename "$BIOS_FD")
    ACTUAL=$(md5sum "$BIOS_FD" | cut -d " " -f 1)
    EXPECTED=$(grep "$FILENAME" "$MD5_FILE" | cut -d " " -f 1)
    if [ "$ACTUAL" = "$EXPECTED" ]; then
        info "$FILENAME"
        PASS=$((PASS + 1))
    else
        error "$FILENAME - MD5 MISMATCH"
        rm -f "$BIOS_FD"
        FAIL=$((FAIL + 1))
    fi
done

if [ $FAIL -gt 0 ]; then
    error "$FAIL file(s) corrupted and removed. Run script again."
    exit 1
fi
info "$PASS files verified"

# =====================
# STEP 5 - Show menu
# =====================
step "5/7 - Select BIOS version"

BIOS_LIST=()
for f in "${BIOS_DIR}"/F*_sign.fd; do
    [ -f "$f" ] || continue
    BIOS_LIST+=($(basename "$f"))
done

CHOICE=$(zenity --list \
    --title "Select BIOS Version" \
    --text "Current BIOS: $BIOS_VERSION\nModel: $PLATFORM ($MODEL)\n\nSelect which BIOS to flash:" \
    --column "BIOS Version" \
    --column "Description" \
    "${BIOS_LIST[@]}" \
    --width 450 --height 300 2>/dev/null)

if [ -z "$CHOICE" ]; then
    warn "No BIOS selected. Exiting."
    exit 0
fi
info "Selected: $CHOICE"

# =====================
# STEP 6 - Confirm
# =====================
step "6/7 - Confirm flash"

zenity --question \
    --title "Confirm BIOS Flash" \
    --text "About to flash: $CHOICE\n\nCurrent BIOS: $BIOS_VERSION\nModel: $PLATFORM\n\nWARNING: Do NOT power off during flash!\nA backup will be created automatically.\n\nProceed?" \
    --width 400 --height 150 2>/dev/null

if [ $? -ne 0 ]; then
    warn "Cancelled by user"
    exit 0
fi

# =====================
# STEP 7 - Backup and Flash
# =====================
step "7/7 - Flashing BIOS"

# Create backup
echo "Creating BIOS backup..."
mkdir -p ~/BIOS_backup 2>/dev/null
echo -e "$PASSWORD\n" | sudo -S /usr/share/jupiter_bios_updater/h2offt \
    ~/BIOS_backup/jupiter-${BIOS_VERSION}-backup-$(date +%Y%m%d).bin -O 2>/dev/null
info "Backup saved to ~/BIOS_backup/"

# Block auto-updates
echo "Blocking automatic BIOS updates..."
echo -e "$PASSWORD\n" | sudo -S steamos-readonly disable 2>/dev/null
echo -e "$PASSWORD\n" | sudo -S systemctl mask jupiter-biosupdate 2>/dev/null
echo -e "$PASSWORD\n" | sudo -S mkdir -p /foxnet/bios/ 2>/dev/null
echo -e "$PASSWORD\n" | sudo -S touch /foxnet/bios/INHIBIT 2>/dev/null
echo -e "$PASSWORD\n" | sudo -S steamos-readonly enable 2>/dev/null
info "Auto-updates blocked"

# Flash
echo "Flashing $CHOICE... DO NOT POWER OFF!"
echo -e "$PASSWORD\n" | sudo -S /usr/share/jupiter_bios_updater/h2offt \
    "${BIOS_DIR}/${CHOICE}" -all

echo ""
echo "============================================"
info "BIOS flash complete!"
info "Backup: ~/BIOS_backup/"
echo "============================================"
echo ""
echo "Reboot to apply changes."
echo -e "$PASSWORD\n" | sudo -S reboot
