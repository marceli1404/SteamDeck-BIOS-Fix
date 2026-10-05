# SteamDeck BIOS Fix

Fixes the **"md5 hash check failed"** error in [SteamDeck-BIOS-Manager](https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager) caused by silent `curl` download failures.

## One-Click Install

Copy and paste this into the Steam Deck terminal:
```bash
rm -rf ~/SteamDeck-BIOS-Fix 2>/dev/null; git clone https://github.com/marceli1404/SteamDeck-BIOS-Fix.git ~/SteamDeck-BIOS-Fix && cd ~/SteamDeck-BIOS-Fix && chmod +x *.sh && ./install-bios.sh
```

## Quick Diagnose

If the install fails, run this to see why:
```bash
rm -rf ~/SteamDeck-BIOS-Fix 2>/dev/null; git clone https://github.com/marceli1404/SteamDeck-BIOS-Fix.git ~/SteamDeck-BIOS-Fix && cd ~/SteamDeck-BIOS-Fix && chmod +x *.sh && ./diagnose.sh
```

Paste the output and we'll figure out what's wrong.

This will:
1. Check prerequisites (sudo, model, disk space)
2. Fix SSL if broken
3. Download all BIOS files with retry
4. Verify MD5 checksums
5. Show a menu to pick which BIOS version
6. Create backup, flash, and reboot

## The Problem

The original script uses `curl -s` which silently fails on:
- SSL certificate errors (common on fresh SteamOS installs)
- Network timeouts
- Disk full

This causes the BIOS files to never be saved, so the MD5 verification fails with:
```
md5 hash check failed!
md5sum: /home/deck/SteamDeck-BIOS-Manager/BIOS/F7A0110_sign.fd: No such file or directory
```

## Other Scripts

### Diagnose
```bash
./diagnose.sh
```
Runs network/SSL tests and a sample download to identify the exact problem.

### Manual Download Fix
```bash
./fix-downloads.sh
```
Downloads and verifies BIOS files without flashing. Copy them to the original script's directory:
```bash
cp ~/SteamDeck-BIOS-Fix/BIOS/*.fd ~/SteamDeck-BIOS-Manager/BIOS/
```

## Requirements

- Steam Deck running SteamOS (LCD or OLED)
- Internet connection
- `sudo` password set

## Safety

- The scripts now use normal `sudo` credential caching (`sudo -v`) and do not keep your sudo password in a shell variable.
- Crisis Mode no longer assumes the USB drive is `/dev/sda`. It lists removable/USB disks, rejects a selected disk containing critical mounted filesystems, and requires you to type the exact device path before any `wipefs` operation.
- BIOS flashing is inherently risky. Keep the Deck on reliable power and do not interrupt a flash once it starts.

## Files

| File | Purpose |
|------|---------|
| `install-bios.sh` | One-click install — download, verify, flash, reboot |
| `fix-downloads.sh` | Download and verify only (no flash) |
| `diagnose.sh` | Diagnostic tool — identifies the root cause |
| `steamdeck-BIOS-manager.sh` | Original upstream script (included for reference) |
| `md5.txt` | MD5 hashes for verification |
