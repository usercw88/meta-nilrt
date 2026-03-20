# Secure Boot configuration for NILRT
# Include this file in your distro configuration to enable secure boot features
#

# Enable UEFI Secure Boot
DISTRO_FEATURES:append:x64 = " uefi-secure-boot"

# Enable kernel module signing
DISTRO_FEATURES:append = " module-signing"

# Enable integrity and IMA/EVM features (requires meta-integrity layer)
# These features are enabled when uefi-secure-boot is active and meta-integrity layer is present
DISTRO_FEATURES:append = "\
    ${@bb.utils.contains('BBFILE_COLLECTIONS', 'integrity', ' integrity ima', '', d)} \
"

# =====================================================================
# Key Management Configuration
# =====================================================================
# IMPORTANT: The paths below use debug keys from meta-security.
# These keys are PUBLIC and should NEVER be used in production!
#
# For production use, generate your own keys following these steps:
# 1. Create a secure directory for your keys (outside the build tree)
# 2. Run: bitbake openssl-native
# 3. Run: bitbake -c devshell openssl-native
# 4. In the devshell, navigate to your key directory and run:
#    ${INTEGRITY_BASE}/scripts/ima-gen-local-ca.sh
#    ${INTEGRITY_BASE}/scripts/ima-gen-CA-signed.sh
# 5. Update the paths below to point to your keys
# 6. Keep the private keys secure and never commit them to version control
# =====================================================================

# IMA/EVM keys for filesystem integrity
# When uefi-secure-boot is enabled and meta-integrity layer is present, these keys are used
IMA_EVM_KEY_DIR ?= "${@bb.utils.contains('BBFILE_COLLECTIONS', 'integrity', '${INTEGRITY_BASE}/data/debug-keys', '', d)}"
IMA_EVM_PRIVKEY ?= "${IMA_EVM_KEY_DIR}/privkey_ima.pem"
IMA_EVM_X509 ?= "${IMA_EVM_KEY_DIR}/x509_ima.der"
IMA_EVM_ROOT_CA ?= "${IMA_EVM_KEY_DIR}/ima-local-ca.pem"

# IMA policy - enforce signatures on all files
# Available policies (in meta-security/meta-integrity/recipes-security/):
#   - ima_policy_simple: Basic measurement only
#   - ima_policy_hashed: Measurement with hashing
#   - ima_policy_appraise_all: Full appraisal (most secure)
IMA_EVM_POLICY ?= "${@bb.utils.contains('BBFILE_COLLECTIONS', 'integrity', '${INTEGRITY_BASE}/recipes-security/ima_policy_appraise_all/files/ima_policy_appraise_all', '', d)}"

# Kernel module signing keys
# These should be different from IMA keys for better security separation
MODULE_SIG_KEY_DIR ?= "${@bb.utils.contains('BBFILE_COLLECTIONS', 'integrity', '${INTEGRITY_BASE}/data/debug-keys', '', d)}"
MODSIGN_PRIVKEY ?= "${MODULE_SIG_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509 ?= "${MODULE_SIG_KEY_DIR}/x509_modsign.crt"

# UEFI Secure Boot keys (for x64 platforms)
# For production, generate UEFI Secure Boot keys using tools like:
# - efi-keytool
# - sbsigntool
# Keys needed:
#   - Platform Key (PK)
#   - Key Exchange Key (KEK)
#   - Database key (db) - for signing bootloaders and kernels
#   - Forbidden database key (dbx) - for revoked keys
UEFI_SB_KEYS_DIR ?= "${@bb.utils.contains('BBFILE_COLLECTIONS', 'integrity', '${INTEGRITY_BASE}/data/debug-keys', '', d)}"
UEFI_SB_DB_KEY ?= "${UEFI_SB_KEYS_DIR}/db.key"
UEFI_SB_DB_CERT ?= "${UEFI_SB_KEYS_DIR}/db.crt"

# =====================================================================
# Secure Boot Build Options
# =====================================================================

# Sign kernel modules during build
KERNEL_MODULE_SIG = "${@bb.utils.contains('DISTRO_FEATURES', 'module-signing', '1', '0', d)}"
KERNEL_MODULE_SIG_ALL = "${@bb.utils.contains('DISTRO_FEATURES', 'module-signing', '1', '0', d)}"
KERNEL_MODULE_SIG_HASH = "sha256"

# Additional security hardening
# Note: read-only-rootfs is commented out as it's incompatible with some NILRT
# runtime requirements. Enable per-image if needed.
# EXTRA_IMAGE_FEATURES:append = " read-only-rootfs"

# Ensure grub-efi is built with secure boot support
# These modules are needed for signature verification and cryptographic operations
GRUB_BUILDIN:append = " pgp gcry_sha256 gcry_sha512 gcry_rsa"

# =====================================================================
# UEFI Secure Boot Binary Signing
# =====================================================================
# Two signing modes are supported:
#
# 1. LOCAL SIGNING (Development):
#    - Uses sbsign with local private keys
#    - Keys stored in ${UEFI_SB_KEYS_DIR}
#    - Default mode when UEFI_REMOTE_SIGNING = "0"
#
# 2. REMOTE SIGNING (Production - RECOMMENDED):
#    - Sends binaries to secure signing server
#    - Private keys never leave signing server
#    - Enable with: UEFI_REMOTE_SIGNING = "1"
#    - Configure server with remote-signing.inc
#
# To enable remote signing:
#   1. Add to distro config: require remote-signing.inc
#   2. Set in local.conf:
#        UEFI_REMOTE_SIGNING = "1"
#        UEFI_SIGNING_SERVER_URL = "https://signing.example.com/api/sign"
#        UEFI_SIGNING_AUTH_TOKEN = "your-secret-token"
#
# Components automatically signed:
# - Kernel (bzImage) → Signed during kernel build
# - GRUB bootloader (grubx64.efi) → Signed during GRUB build
# - Images use signed binaries when available
#
# For enhanced security, consider using shim bootloader as first-stage bootloader
# to enable fallback and revocation capabilities.
