# SteamDeck BIOS Fix

Fixes the **"md5 hash check failed"** error in [SteamDeck-BIOS-Manager](https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager) caused by silent `curl` download failures.

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

## The Fix

### Quick Fix
```bash
cd ~/SteamDeck-BIOS-Fix
chmod +x fix-downloads.sh
./fix-downloads.sh
```

This script:
1. Checks disk space (needs 500MB+)
2. Tests SSL connectivity to gitlab.com, deckhd.com, balika011.hu
3. Fixes SSL certs if broken (`ca-certificates` package)
4. Downloads all BIOS files with **retry logic** (3 attempts per file)
5. Verifies MD5 hashes against `md5.txt`

### Diagnose First
```bash
chmod +x diagnose.sh
./diagnose.sh
```

This runs network/SSL tests and a sample download to identify the exact problem.

## After Running

Copy the BIOS files to the original script's directory:
```bash
cp ~/SteamDeck-BIOS-Fix/BIOS/*.fd ~/SteamDeck-BIOS-Manager/BIOS/
```

Then use the original SteamDeck-BIOS-Manager as normal.

## Requirements

- Steam Deck running SteamOS (LCD or OLED)
- Internet connection
- `sudo` password set

## Files

| File | Purpose |
|------|---------|
| `fix-downloads.sh` | Main fix — downloads and verifies BIOS files |
| `diagnose.sh` | Diagnostic tool — identifies the root cause |
| `md5.txt` | MD5 hashes for verification (from upstream) |
