SUMMARY = "Remote signing tools for UEFI Secure Boot"
DESCRIPTION = "Python-based tool for sending EFI binaries to a remote signing server"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://remote-sign-efi.py"

S = "${WORKDIR}"

RDEPENDS:${PN} = "python3-core"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/remote-sign-efi.py ${D}${bindir}/remote-sign-efi
}

BBCLASSEXTEND = "native nativesdk"
