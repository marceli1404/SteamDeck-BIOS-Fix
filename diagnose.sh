#!/bin/bash

# Quick diagnostic tool for SteamDeck-BIOS-Manager download issues
# Run this first to identify the problem

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo " SteamDeck BIOS Download Diagnostics"
echo "========================================"
echo ""

# Model detection
MODEL=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "Unknown")
BIOS_VER=$(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo "Unknown")
echo "Model:       $MODEL"
echo "BIOS:        $BIOS_VER"
echo "Free space:  $(df -BM ~ | awk 'NR==2 {print $4}')MB"
echo "User:        $(whoami)"
echo ""

# Network tests
echo "--- Network Tests ---"
echo -n "gitlab.com:      "
if curl -sI --connect-timeout 5 https://gitlab.com > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo -n "deckhd.com:      "
if curl -sI --connect-timeout 5 https://www.deckhd.com > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}FAIL (non-critical)${NC}"
fi

echo -n "balika011.hu:    "
if curl -sI --connect-timeout 5 https://balika011.hu > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}FAIL (non-critical)${NC}"
fi

echo ""

# SSL cert check
echo "--- SSL Certificate Check ---"
echo -n "CA bundle:       "
if [ -f /etc/ssl/certs/ca-certificates.crt ] || [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then
    echo -e "${GREEN}Found${NC}"
else
    echo -e "${RED}Missing - run: sudo pacman -S ca-certificates${NC}"
fi

echo -n "SSL test:        "
if curl -sL --connect-timeout 5 -o /dev/null -w "%{http_code}" https://gitlab.com 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL - SSL handshake error${NC}"
    echo "  Fix: sudo steamos-readonly disable && sudo pacman -S ca-certificates && sudo steamos-readonly enable"
fi

echo ""

# Test a real BIOS download
echo "--- Download Test (F7A0110_sign.fd, ~16MB) ---"
TEST_DIR=$(mktemp -d)
echo -n "Downloading:     "
HTTP_CODE=$(curl -sL --connect-timeout 10 --max-time 30 -o "${TEST_DIR}/test.fd" -w "%{http_code}" \
    "https://gitlab.com/evlaV/jupiter-hw-support/-/raw/0660b2a5a9df3bd97751fe79c55859e3b77aec7d/usr/share/jupiter_bios/F7A0110_sign.fd" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] && [ -s "${TEST_DIR}/test.fd" ]; then
    FILE_SIZE=$(du -h "${TEST_DIR}/test.fd" | cut -f1)
    echo -e "${GREEN}OK${NC} ($FILE_SIZE)"
    echo -n "MD5 check:       "
    ACTUAL=$(md5sum "${TEST_DIR}/test.fd" | cut -d " " -f 1)
    EXPECTED="098e1422362f4d69b32a3c073ed7cb1a"
    if [ "$ACTUAL" = "$EXPECTED" ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL (expected: $EXPECTED, got: $ACTUAL)${NC}"
    fi
else
    echo -e "${RED}FAIL${NC} (HTTP $HTTP_CODE)"
    if [ -f "${TEST_DIR}/test.fd" ]; then
        echo "  Response body: $(head -c 200 "${TEST_DIR}/test.fd")"
    fi
fi
rm -rf "$TEST_DIR"

echo ""

# Check existing BIOS files
echo "--- Existing BIOS Files ---"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/BIOS" ]; then
    COUNT=$(ls "${SCRIPT_DIR}/BIOS/"*.fd 2>/dev/null | wc -l)
    echo "Found $COUNT .fd files in ${SCRIPT_DIR}/BIOS/"
    ls -lh "${SCRIPT_DIR}/BIOS/"*.fd 2>/dev/null
else
    echo "No BIOS/ directory found"
fi

echo ""
echo "========================================"
echo " If download test failed, run fix-downloads.sh"
echo "========================================"
