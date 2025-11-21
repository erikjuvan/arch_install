#!/usr/bin/env bash
set -euo pipefail # exit on errors, treat unset variables as errors, fail if any command in a pipeline fails
set -x # Print commands as they are executed
trap 'echo "Error on line $LINENO"; exit 1' ERR
exec > >(tee "install.log") 2>&1 # Redirect all commands to file

echo "====================="
echo "Installation started."
echo "====================="
echo

# --------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------
BASE_INSTALLER_SCRIPT=install_base.sh
EXTRA_PACKAGES_FILE=packages_extra.txt
GUI_PACKAGES_FILE=packages_gui.txt
PACKAGE_PARSER_SCRIPT=parse_packages.sh

# --------------------------------------------------------------
# SOURCE GUI PACKAGE PARSER SCRIPT
# --------------------------------------------------------------
source "./$PACKAGE_PARSER_SCRIPT"

# --------------------------------------------------------------
# LIST GUI PACKAGE OPTIONS AND CHOOSE OPTION
# --------------------------------------------------------------
list_options "$GUI_PACKAGES_FILE"
read -rp "Choose GUI [press Enter to skip]: " DESKTOP_ENV

# --------------------------------------------------------------
# CALL BASE INSTALLER
# --------------------------------------------------------------
source "./$BASE_INSTALLER_SCRIPT"

# --------------------------------------------------------------
# MOUNT ROOT PARTITION
# --------------------------------------------------------------
# Make sure /mnt is mounted for extra package installation
mount "$PARTITION" /mnt

# --------------------------------------------------------------
# INSTALL EXTRA PACKAGES
# --------------------------------------------------------------
pacstrap -K /mnt $(sed -E 's/#.*//; /^\s*$/d' "$EXTRA_PACKAGES_FILE") --needed

# --------------------------------------------------------------
# INSTALL OPTIONAL DE/WM AND GUI PACKAGES
# --------------------------------------------------------------
if [[ -n "$DESKTOP_ENV" ]]; then # test if DESKTOP_ENV is not empty
    # Capture packages
    GUI_PACKAGES=$(parse_packages "$DESKTOP_ENV" "$GUI_PACKAGES_FILE")
    SCRIPT_EXIT_CODE=$?

    # Only proceed if packages were found
    if [[ $SCRIPT_EXIT_CODE -eq 0 ]]; then
        # Install GUI packages
        pacstrap /mnt $GUI_PACKAGES --needed

        # Enable SDDM
        arch-chroot /mnt systemctl enable sddm

        # dofiles config alacritty
        arch-chroot /mnt sudo -u "$USERNAME" bash -c "
        mkdir -p /home/$USERNAME/.config/alacritty
        ln -sf /home/$USERNAME/.dotfiles/.config/alacritty/alacritty.yml /home/$USERNAME/.config/alacritty/alacritty.yml
        "
    else
        echo "Warning: Invalid GUI package chosen."
    fi
fi

# --------------------------------------------------------------
# FINALIZE
# --------------------------------------------------------------
echo "======================"
echo "Installation complete."
echo "======================"
echo
echo "Remove ISO and reboot manually."

cp install.log "/mnt/home/$USERNAME/"

umount -R /mnt || true
