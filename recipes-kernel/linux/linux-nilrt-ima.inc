# IMA/EVM kernel configuration for NILRT
# Based on meta-security/meta-integrity/recipes-kernel/linux/linux_ima.inc

do_configure:append() {
    if [ "${@bb.utils.contains('DISTRO_FEATURES', 'ima', 'yes', '', d)}" = "yes" ] && [ -f .config ] ; then
        # Configure the kernel to trust the IMA/EVM root CA
        sed -i "s|^CONFIG_SYSTEM_TRUSTED_KEYS=.*|CONFIG_SYSTEM_TRUSTED_KEYS=\"${IMA_EVM_ROOT_CA}\"|" .config
    fi
}

SRC_URI:append = " ${@bb.utils.contains('DISTRO_FEATURES', 'ima', ' file://features/ima/ima.scc file://features/ima/ima.cfg', '', d)}"

# Add IMA/EVM kernel feature fragments when enabled
KERNEL_FEATURES:append = " ${@bb.utils.contains('DISTRO_FEATURES', 'modsign', ' features/ima/modsign.scc', '', d)}"
KERNEL_FEATURES:append = " ${@bb.utils.contains('DISTRO_FEATURES', 'ima', ' ima.scc', '', d)}"

# Inherit kernel module signing class when module-signing is enabled
inherit ${@bb.utils.contains('DISTRO_FEATURES', 'modsign', 'kernel-modsign', '', d)}
