# Class for signing GRUB EFI binaries for UEFI Secure Boot
# Supports both local signing (with sbsign) and remote signing via secure server

# Sign GRUB EFI binaries after they're installed
do_sign_grub() {
    if [ "${@bb.utils.contains('DISTRO_FEATURES', 'uefi-secure-boot', 'true', 'false', d)}" = "true" ]; then

        # Sign both the default GRUB image and the NILRT-specific image
        for GRUB_UNSIGNED in "${D}/boot/efi/EFI/BOOT/${GRUB_IMAGE}" "${D}/boot/efi/nilrt/${GRUB_IMAGE}"; do
            if [ ! -f "${GRUB_UNSIGNED}" ]; then
                bbnote "GRUB image not found: ${GRUB_UNSIGNED}, skipping"
                continue
            fi

            GRUB_SIGNED="${GRUB_UNSIGNED}.signed"

            # Check if remote signing is enabled
            if [ "${UEFI_REMOTE_SIGNING}" = "1" ]; then
                bbnote "Using remote signing server for GRUB image: ${GRUB_UNSIGNED}"

                if [ -z "${UEFI_SIGNING_SERVER_URL}" ]; then
                    bbfatal "UEFI_REMOTE_SIGNING is enabled but UEFI_SIGNING_SERVER_URL is not set"
                fi

                # Build remote-sign-efi command
                REMOTE_SIGN_CMD="remote-sign-efi"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD '${GRUB_UNSIGNED}' '${GRUB_SIGNED}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --server-url '${UEFI_SIGNING_SERVER_URL}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --auth-method '${UEFI_SIGNING_AUTH_METHOD}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --component-type 'grub'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --timeout '${UEFI_SIGNING_TIMEOUT}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --retries '${UEFI_SIGNING_RETRIES}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --retry-delay '${UEFI_SIGNING_RETRY_DELAY}'"
                REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --verify '${UEFI_VERIFY_SIGNED}'"

                if [ "${UEFI_SIGNING_AUTH_METHOD}" = "token" ] && [ -n "${UEFI_SIGNING_AUTH_TOKEN}" ]; then
                    REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --auth-token '${UEFI_SIGNING_AUTH_TOKEN}'"
                fi

                if [ "${UEFI_SIGNING_AUTH_METHOD}" = "cert" ]; then
                    if [ -n "${UEFI_SIGNING_CLIENT_CERT}" ]; then
                        REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --client-cert '${UEFI_SIGNING_CLIENT_CERT}'"
                    fi
                    if [ -n "${UEFI_SIGNING_CLIENT_KEY}" ]; then
                        REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --client-key '${UEFI_SIGNING_CLIENT_KEY}'"
                    fi
                fi

                bbnote "Signing GRUB remotely: $(basename ${GRUB_UNSIGNED})"
                eval $REMOTE_SIGN_CMD

                if [ $? -eq 0 ]; then
                    bbnote "GRUB signed successfully via remote server: $(basename ${GRUB_SIGNED})"
                    # Replace unsigned with signed
                    mv "${GRUB_SIGNED}" "${GRUB_UNSIGNED}"
                else
                    bbfatal "Failed to sign GRUB image via remote server: ${GRUB_UNSIGNED}"
                fi

            else
                # Local signing with sbsign
                bbnote "Using local signing with sbsign for GRUB image"

                if [ ! -f "${UEFI_SB_DB_KEY}" ] || [ ! -f "${UEFI_SB_DB_CERT}" ]; then
                    bbwarn "UEFI Secure Boot is enabled but keys are not found:"
                    bbwarn "  Key: ${UEFI_SB_DB_KEY}"
                    bbwarn "  Cert: ${UEFI_SB_DB_CERT}"
                    bbwarn "GRUB will not be signed. Set UEFI_REMOTE_SIGNING=1 to use remote signing."
                    return
                fi

                bbnote "Signing GRUB image ${GRUB_UNSIGNED} for UEFI Secure Boot"
                sbsign --key "${UEFI_SB_DB_KEY}" \
                       --cert "${UEFI_SB_DB_CERT}" \
                       --output "${GRUB_SIGNED}" \
                       "${GRUB_UNSIGNED}"

                if [ $? -eq 0 ]; then
                    bbnote "GRUB signed successfully: $(basename ${GRUB_SIGNED})"
                    # Replace unsigned with signed
                    mv "${GRUB_SIGNED}" "${GRUB_UNSIGNED}"
                else
                    bbfatal "Failed to sign GRUB image with sbsign: ${GRUB_UNSIGNED}"
                fi
            fi
        done
    fi
}

do_sign_grub[depends] += "${@bb.utils.contains('UEFI_REMOTE_SIGNING', '1', 'uefi-remote-signing-native:do_populate_sysroot', '', d)}"
addtask sign_grub after do_install before do_populate_sysroot do_package
