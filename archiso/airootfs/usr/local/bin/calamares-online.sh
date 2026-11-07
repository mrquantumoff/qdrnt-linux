#!/bin/bash

main() {
    # Fresh pacman keyring before the installer touches any package.
    if ! sudo /usr/local/bin/qdrnt-refresh-keyring; then
        echo "WARNING: pacman keyring refresh failed; installation may hit signature errors." >&2
    fi

    local progname="$(basename "$0")"
    local log="/home/liveuser/cachy-install.log"
    local mode="online"

    local SYSTEM=""

    if [ -d /sys/firmware/efi ]; then
        SYSTEM="UEFI SYSTEM"
    else
        SYSTEM="BIOS/MBR SYSTEM"
    fi

    local ISO_VERSION="$(cat /etc/version-tag)"
    echo "USING ISO VERSION: ${ISO_VERSION}"

    # The qdrnt installer (qdrnt-calamares, built from the calamares submodule)
    # is baked into the ISO. Don't pull cachyos-calamares-next from the repos:
    # it would replace the qdrnt configuration.

    # Get Hardware Informations
    inxi -F > "$log"

    cat <<EOT >> "$log"
########## $log by $progname
########## Started (UTC): $(date -u "+%x %X")
########## ISO version: $ISO_VERSION
########## System: $SYSTEM
EOT

    sudo cp "/usr/share/calamares/settings_${mode}.conf" /etc/calamares/settings.conf
    exec pkexec-wrapper calamares -D6 >> $log
}

main "$@"
