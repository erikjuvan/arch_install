#!/usr/bin/env bash
set -euo pipefail # exit on errors, treat unset variables as errors, fail if any command in a pipeline fails
set -x # Print commands as they are executed
trap 'echo "Error on line $LINENO"; exit 1' ERR
exec > >(tee "install.log") 2>&1 # Redirect all commands to file

echo "==========================="
echo "Installation started."
echo "==========================="
echo

# --------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------
CORE_INSTALLER_SCRIPT=arch_install_core.sh
BASE_PACKAGES_FILE="packages_base.txt"
GUI_PACKAGES_FILE="packages_gui.txt"
PACKAGE_PARSER_SCRIPT="parse_packages.sh"
DOTFILES_REPO="https://github.com/erikjuvan/dotfiles"
DESKTOP_ENV="${DESKTOP_ENV:-none}"  # For options see packages_gui.txt

# --------------------------------------------------------------
# SOURCE GUI PACKAGE PARSER SCRIPT
# --------------------------------------------------------------
source "./$PACKAGE_PARSER_SCRIPT"

# --------------------------------------------------------------
# LIST GUI PACKAGE OPTIONS AND CHOSEN OPTION
# --------------------------------------------------------------
echo "Available DE/WM (choose one by setting DESKTOP_ENV):"
list_options "$GUI_PACKAGES_FILE"
echo "Choosing: $DESKTOP_ENV"

# --------------------------------------------------------------
# CALL CORE INSTALLER
# --------------------------------------------------------------
# This will do disk setup, core packages, user, GRUB, autologin
# Also variables from core script are available
source "./$CORE_INSTALLER_SCRIPT"

# --------------------------------------------------------------
# MOUNT ROOT PARTITION
# --------------------------------------------------------------
# Make sure /mnt is mounted for extra package installation
mount "$PARTITION" /mnt

# --------------------------------------------------------------
# INSTALL ADDITIONAL (BASE) PACKAGES - setup my base of work
# --------------------------------------------------------------
pacstrap -K /mnt $(sed -E 's/#.*//; /^\s*$/d' "$BASE_PACKAGES_FILE") --needed

# --------------------------------------------------------------
# INSTALL OPTIONAL DE/WM AND GUI PACKAGES
# --------------------------------------------------------------
if [[ "$DESKTOP_ENV" != "none" ]]; then
    # Capture packages
    GUI_PACKAGES=$(parse_packages "$DESKTOP_ENV" "$GUI_PACKAGES_FILE")
    SCRIPT_EXIT_CODE=$?

    # Only proceed if packages were found
    if [[ $SCRIPT_EXIT_CODE -eq 0 ]]; then
        pacstrap /mnt $GUI_PACKAGES --needed
        arch-chroot /mnt systemctl enable sddm
    else
        echo "No GUI packages to install."
    fi
fi

# --------------------------------------------------------------
# DEPLOY DOTFILES
# --------------------------------------------------------------
arch-chroot /mnt sudo -u "$USERNAME" bash <<EOF
set -e
DOTDIR="/home/$USERNAME/.dotfiles"
git clone --depth=1 "$DOTFILES_REPO" "\$DOTDIR" || true

ln -sf "\$DOTDIR/.xinitrc" "/home/$USERNAME/.xinitrc"
ln -sf "\$DOTDIR/.xprofile" "/home/$USERNAME/.xprofile"
ln -sf "\$DOTDIR/.gitconfig" "/home/$USERNAME/.gitconfig"

mkdir -p "/home/$USERNAME/.config/alacritty"
ln -sf "\$DOTDIR/.config/alacritty/alacritty.yml" "/home/$USERNAME/.config/alacritty/alacritty.yml"

mkdir -p "/home/$USERNAME/.config/fish"
ln -sf "\$DOTDIR/.config/fish/config.fish" "/home/$USERNAME/.config/fish/config.fish"

ln -sf "\$DOTDIR/.config/nvim" "/home/$USERNAME/.config/nvim" || true
EOF

# --------------------------------------------------------------
# FINALIZE
# --------------------------------------------------------------
cp install.log "/mnt/home/$USERNAME/"
umount -R /mnt || true

echo "======================"
echo "Installation complete."
echo "======================"
echo
echo "Remove ISO and reboot manually."
