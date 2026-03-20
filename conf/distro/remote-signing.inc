# Remote signing server configuration for UEFI Secure Boot
# Set these variables in your local.conf to enable remote signing

# Enable remote signing instead of local signing
# Set to "1" to use a remote signing server
UEFI_REMOTE_SIGNING ?= "0"

# Signing server URL
# Example: "https://signing-server.example.com/api/sign"
UEFI_SIGNING_SERVER_URL ?= ""

# Authentication method: "token", "cert", or "none"
UEFI_SIGNING_AUTH_METHOD ?= "token"

# Authentication token (for token-based auth)
# This should be set in local.conf, not committed to git
UEFI_SIGNING_AUTH_TOKEN ?= ""

# Client certificate and key (for cert-based auth)
UEFI_SIGNING_CLIENT_CERT ?= ""
UEFI_SIGNING_CLIENT_KEY ?= ""

# Signing timeout in seconds
UEFI_SIGNING_TIMEOUT ?= "300"

# Component type identifier sent to server
# Helps server route to appropriate signing key
# Valid values: "kernel", "grub", or custom types
# Note: kernel-uefi-sign.bbclass uses "kernel"
#       grub-uefi-sign.bbclass uses "grub"
UEFI_COMPONENT_TYPE ?= "kernel"

# Retry configuration
UEFI_SIGNING_RETRIES ?= "3"
UEFI_SIGNING_RETRY_DELAY ?= "5"

# Verify signed binaries (recommended)
UEFI_VERIFY_SIGNED ?= "1"
