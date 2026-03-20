# Enable IMA/EVM and secure boot features for NILRT kernels
# This mirrors the configuration from meta-security/meta-integrity

FILESEXTRAPATHS:prepend := "${THISDIR}/linux-nilrt:"

# Include IMA/EVM configuration when integrity features are enabled
require ${@bb.utils.contains_any('DISTRO_FEATURES', 'integrity ', 'linux-nilrt-ima.inc', '', d)}
