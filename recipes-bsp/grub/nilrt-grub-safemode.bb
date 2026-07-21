SUMMARY = "NILRT safemode grub configuration"
DESCRIPTION = "NILRT distro-specific safemode boot files"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
SECTION = "base"

inherit user-key-store

FILESEXTRAPATHS:prepend := "${THISDIR}/grub:"

SRC_URI += " \
    file://grub-efi.cfg \
    file://grubenv \
    file://grub-safemode.cfg \
    file://grub-safemode-bootimage.cfg \
"

FILES:${PN} += " \
    /boot/bootimage.cfg \
    /boot/grub-safemode.cfg \
    /boot/grub-safemode.cfg${SB_FILE_EXT} \
    /boot/grubenv \
"

CONFFILES:${PN} += " \
    /boot/bootimage.cfg \
    /boot/grub-safemode.cfg \
    /boot/grubenv \
"

do_install () {
    combined_grub_cfg=${T}/grub-safemode-combined.cfg
    awk '
        /^if \[ -s ".*\/grub-safemode\.cfg" \]; then$/ { skip=1; next }
        skip && /^fi$/ { skip=0; next }
        !skip { print }
    ' ${WORKDIR}/grub-efi.cfg > ${combined_grub_cfg}
    printf '\n' >> ${combined_grub_cfg}
    cat ${WORKDIR}/grub-safemode.cfg >> ${combined_grub_cfg}

	install -d ${D}/boot
	install -m 0644 ${WORKDIR}/grub-safemode-bootimage.cfg ${D}/boot/bootimage.cfg
    install -m 0644 ${combined_grub_cfg} ${D}/boot/grub-safemode.cfg
	install -m 0644 ${WORKDIR}/grubenv ${D}/boot/grubenv
}

do_sign[prefuncs] += "${@bb.utils.contains('DISTRO_FEATURES', 'efi-secure-boot', 'check_deploy_keys check_boot_public_key', '', d)}"

python __anonymous () {
    if not bb.utils.contains('DISTRO_FEATURES', 'efi-secure-boot', True, False, d):
        d.setVarFlag('do_sign', 'noexec', '1')
}

fakeroot python do_sign () {
    import os

    boot_dir = d.expand('${D}/boot')
    for name in ('grub-safemode.cfg',):
        path = os.path.join(boot_dir, name)
        if os.path.exists(path):
            uks_bl_sign(path, d)
}

addtask sign after do_install before do_package
