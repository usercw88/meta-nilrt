# Remote Signing for UEFI Secure Boot

This document describes how to configure NILRT builds to use a remote signing server for UEFI Secure Boot components.

## Overview

Remote signing is the **recommended approach for production** because:
- Private keys never leave the secure signing server
- Reduces attack surface on build infrastructure
- Enables centralized key management and auditing
- Supports HSM (Hardware Security Module) backed signing

## Architecture

```
┌─────────────┐                  ┌──────────────────┐
│   Bitbake   │                  │  Signing Server  │
│    Build    │                  │  (Secure HSM)    │
├─────────────┤                  ├──────────────────┤
│             │                  │                  │
│  1. Build   │                  │  - Private Keys  │
│  bzImage    │                  │  - HSM Storage   │
│             │                  │  - Audit Logs    │
│  2. Send ──────────────────────>  3. Sign with    │
│  unsigned   │   HTTPS/TLS      │     UEFI keys    │
│             │                  │                  │
│  4. Receive <──────────────────   5. Return       │
│  signed     │                  │     signed       │
│             │                  │                  │
│  6. Deploy  │                  │                  │
│  to image   │                  │                  │
└─────────────┘                  └──────────────────┘
```

## Configuration

### Step 1: Enable Remote Signing in Distro Config

Add to `conf/distro/nilrt.conf`:

```bitbake
require nilrt.inc
require secureboot.inc
require remote-signing.inc
```

### Step 2: Configure in local.conf

Add to `build/conf/local.conf`:

```bitbake
# Enable remote signing
UEFI_REMOTE_SIGNING = "1"

# Signing server URL
UEFI_SIGNING_SERVER_URL = "https://signing-server.example.com/api/v1/sign"

# Authentication
UEFI_SIGNING_AUTH_METHOD = "token"
UEFI_SIGNING_AUTH_TOKEN = "${@os.getenv('SIGNING_TOKEN', '')}"

# Note: UEFI_COMPONENT_TYPE is automatically set by signing classes:
#   - kernel-uefi-sign.bbclass sets it to "kernel"
#   - grub-uefi-sign.bbclass sets it to "grub"
# You typically don't need to override this manually.
```

### Step 3: Set Authentication Token

**Important:** Never commit tokens to version control!

```bash
# Set via environment variable
export SIGNING_TOKEN="your-secret-token-here"

# Or store in a separate file
echo "your-secret-token" > ~/.signing-token
chmod 600 ~/.signing-token

# Reference in local.conf
UEFI_SIGNING_AUTH_TOKEN = "${@open(os.path.expanduser('~/.signing-token')).read().strip()}"
```

### Step 4: Build

```bash
bitbake nilrt-safemode-rootfs
```

The kernel will automatically be sent to the signing server and the signed version used in the image.

## Signing Server API

The signing server must implement this API:

### Endpoint

```
POST /api/v1/sign
```

### Request

Multipart form data with:
- `file`: Binary file to sign (bzImage, grubx64.efi, etc.)
- `metadata`: JSON with:
  ```json
  {
    "component_type": "kernel",  # or "grub" for bootloader
    "filename": "bzImage",
    "hash_algorithm": "sha256",
    "unsigned_hash": "abc123..."
  }
  ```

### Authentication

**Token-based:**
```
Authorization: Bearer <token>
```

**Certificate-based:**
- Client certificate verification via TLS

### Response

- **Success (200 OK)**: Binary signed file
- **Error (4xx/5xx)**: JSON error message

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `UEFI_REMOTE_SIGNING` | `0` | Enable remote signing (1=yes, 0=no) |
| `UEFI_SIGNING_SERVER_URL` | `""` | Signing server endpoint URL |
| `UEFI_SIGNING_AUTH_METHOD` | `token` | Auth method: token, cert, or none |
| `UEFI_SIGNING_AUTH_TOKEN` | `""` | Bearer token for authentication |
| `UEFI_SIGNING_CLIENT_CERT` | `""` | Client certificate for cert auth |
| `UEFI_SIGNING_CLIENT_KEY` | `""` | Client key for cert auth |
| `UEFI_COMPONENT_TYPE` | `kernel` | Component identifier (auto-set by bbclass: "kernel" or "grub") |
| `UEFI_SIGNING_TIMEOUT` | `300` | Request timeout (seconds) |
| `UEFI_SIGNING_RETRIES` | `3` | Number of retry attempts |
| `UEFI_SIGNING_RETRY_DELAY` | `5` | Delay between retries (seconds) |
| `UEFI_VERIFY_SIGNED` | `1` | Verify signature after signing |

## Security Best Practices

1. **Use HTTPS**: Always use TLS for signing server communication
2. **Rotate Tokens**: Regularly rotate authentication tokens
3. **Audit Logs**: Enable server-side audit logging of all signing requests
4. **Network Isolation**: Place signing server in isolated network segment
5. **Rate Limiting**: Implement rate limiting on signing endpoint
6. **HSM Storage**: Store private keys in Hardware Security Module
7. **Access Control**: Restrict signing server access by IP/certificate

## Troubleshooting

### Build fails with "signing server timeout"
- Check network connectivity to signing server
- Increase `UEFI_SIGNING_TIMEOUT`
- Check signing server logs

### Build fails with "authentication failed"
- Verify `UEFI_SIGNING_AUTH_TOKEN` is set correctly
- Check token hasn't expired
- Verify token has permissions for signing

### Signed binary verification fails
- Check server is using correct signing key
- Verify certificate chain is valid
- Check `UEFI_SB_DB_CERT` matches server's signing certificate

## Local Signing (Development Only)

For development/testing, you can use local signing:

```bitbake
# Disable remote signing
UEFI_REMOTE_SIGNING = "0"

# Set local keys
UEFI_SB_DB_KEY = "/path/to/db.key"
UEFI_SB_DB_CERT = "/path/to/db.crt"
```

**Warning:** Local signing requires private keys on the build server. Only use for development!

## Example Signing Server Implementation

See `scripts/signing-server-example/` for a reference Flask-based signing server implementation.

## See Also

- [secureboot.inc](secureboot.inc) - Main secure boot configuration
- [remote-signing.inc](remote-signing.inc) - Remote signing variables
- [kernel-uefi-sign.bbclass](../../classes/kernel-uefi-sign.bbclass) - Kernel signing class
