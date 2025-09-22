# Ligolo-ng Stealth Agent Build Scripts

## Available Scripts

### 1. `build.sh` (Primary - Works with Go 1.24+)
**Current production script** - Use this for immediate builds.

```bash
./build.sh
```

**Features:**
- Manual string obfuscation
- Memory layout padding to evade signature detection
- UPX compression
- Symbol stripping
- Works with current Go 1.24.4

**Output:**
- `agent-stealth-final-upx.exe` (2.7MB) - **Recommended**
- `agent-stealth-alt-upx.exe` (2.7MB) - Alternative
- Plus uncompressed versions

### 2. `build-garble.sh` (Advanced - Requires Go 1.25+)
**Future upgrade script** - Use when you upgrade to Go 1.25+.

```bash
./build-garble.sh
```

**Features:**
- Full garble obfuscation (function names, variables, control flow)
- String literal obfuscation
- Binary size optimization
- Random seeds for unique builds
- Maximum AV evasion

**Output:**
- `agent-garbled-tiny-upx.exe` - **Best evasion**
- Multiple variants with different obfuscation levels

## Quick Start

1. **For immediate use:**
   ```bash
   ./build.sh
   ```

2. **Test the recommended binary:**
   ```bash
   # Use this one first
   agent-stealth-final-upx.exe
   ```

## Evasion Techniques Applied

- ✅ **String obfuscation** - Changes `Ligolo-ng` → `NetAgent`, etc.
- ✅ **Memory layout disruption** - Adds 2KB+ padding to shift data sections
- ✅ **Symbol stripping** - Removes debug symbols (`-s -w`)
- ✅ **UPX compression** - Changes binary signature
- ✅ **Path trimming** - Removes build paths
- ✅ **Custom build info** - Changes version strings

## AV Testing Notes

The original detection was at offset `0x69A27F` with these bytes:
```
16 50 a7 f4 51 53 65 41 7e c3 a4 17 1a 96 5e 27
```

Our builds have completely different bytes at that location, which should evade the `Trojan:Win32/Wacatac.B!ml` detection.

## File Cleanup

After building, you can clean up with:
```bash
rm -f agent-*.exe
```