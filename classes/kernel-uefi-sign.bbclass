# Class for signing kernel images for UEFI Secure Boot
# Supports both local signing (with sbsign) and remote signing via secure server

# Sign the kernel image after it's built
do_sign_kernel() {
    if [ "${@bb.utils.contains('DISTRO_FEATURES', 'uefi-secure-boot', 'true', 'false', d)}" = "true" ]; then

        UNSIGNED_KERNEL="${KERNEL_OUTPUT_DIR}/${KERNEL_IMAGETYPE}"
        SIGNED_KERNEL="${KERNEL_OUTPUT_DIR}/${KERNEL_IMAGETYPE}.signed"

        # Check if remote signing is enabled
        if [ "${UEFI_REMOTE_SIGNING}" = "1" ]; then
            bbnote "Using remote signing server for kernel image"

            if [ -z "${UEFI_SIGNING_SERVER_URL}" ]; then
                bbfatal "UEFI_REMOTE_SIGNING is enabled but UEFI_SIGNING_SERVER_URL is not set"
            fi

            # Build remote-sign-efi command
            REMOTE_SIGN_CMD="remote-sign-efi"
            REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD '${UNSIGNED_KERNEL}' '${SIGNED_KERNEL}'"
            REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --server-url '${UEFI_SIGNING_SERVER_URL}'"
            REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --auth-method '${UEFI_SIGNING_AUTH_METHOD}'"
            REMOTE_SIGN_CMD="$REMOTE_SIGN_CMD --component-type '${UEFI_COMPONENT_TYPE}'"
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

            bbnote "Signing kernel remotely: ${KERNEL_IMAGETYPE}"
            eval $REMOTE_SIGN_CMD

            if [ $? -eq 0 ]; then
                bbnote "Kernel signed successfully via remote server: ${KERNEL_IMAGETYPE}.signed"
            else
                bbfatal "Failed to sign kernel image via remote server"
            fi

        else
            # Local signing with sbsign
            bbnote "Using local signing with sbsign for kernel image"

            if ! PSEUDO_UNLOAD=1 test -f "${UEFI_SB_DB_KEY}" || ! PSEUDO_UNLOAD=1 test -f "${UEFI_SB_DB_CERT}"; then
                bbwarn "UEFI Secure Boot is enabled but keys are not found:"
                bbwarn "  Key: ${UEFI_SB_DB_KEY}"
                bbwarn "  Cert: ${UEFI_SB_DB_CERT}"
                bbwarn "Kernel will not be signed. Set UEFI_REMOTE_SIGNING=1 to use remote signing."
                return
            fi

            bbnote "Signing kernel image ${UNSIGNED_KERNEL} for UEFI Secure Boot"
            PSEUDO_UNLOAD=1 sbsign --key "${UEFI_SB_DB_KEY}" \
                                 --cert "${UEFI_SB_DB_CERT}" \
                                 --output "${SIGNED_KERNEL}" \
                                 "${UNSIGNED_KERNEL}"

            if [ $? -eq 0 ]; then
                bbnote "Kernel signed successfully: ${KERNEL_IMAGETYPE}.signed"
            else
                bbfatal "Failed to sign kernel image with sbsign"
            fi
        fi
    fi
}

do_sign_kernel[depends] += "${@bb.utils.contains('UEFI_REMOTE_SIGNING', '1', 'uefi-remote-signing-native:do_populate_sysroot', '', d)}"
addtask sign_kernel after do_bundle_initramfs before do_deploy

# Deploy the signed kernel
do_deploy:append() {
    if [ "${@bb.utils.contains('DISTRO_FEATURES', 'uefi-secure-boot', 'true', 'false', d)}" = "true" ]; then
        if [ -f "${KERNEL_OUTPUT_DIR}/${KERNEL_IMAGETYPE}.signed" ]; then
            install -m 0644 "${KERNEL_OUTPUT_DIR}/${KERNEL_IMAGETYPE}.signed" \
                "${DEPLOYDIR}/${KERNEL_IMAGETYPE}.signed"
            bbnote "Deployed signed kernel: ${DEPLOYDIR}/${KERNEL_IMAGETYPE}.signed"
        fi
    fi
}
