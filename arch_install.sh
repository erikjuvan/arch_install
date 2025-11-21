#!/usr/bin/env bash
set -euo pipefail # exit on errors, treat unset variables as errors, fail if any command in a pipeline fails
set -x # Print commands as they are executed
trap 'echo "Error on line $LINENO"; exit 1' ERR

# --------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------
BASE_PACKAGES_FILE="packages_base.txt"
GUI_PACKAGES_FILE="packages_gui.txt"
GUI_PARSES_SCRIPT="parse_gui_packages.sh"
DOTFILES_REPO="https://github.com/erikjuvan/dotfiles"
DESKTOP_ENV="${DESKTOP_ENV:-none}"  # For options see packages_gui.txt

# --------------------------------------------------------------
# CALL BASE INSTALLER
# --------------------------------------------------------------
# This will do disk setup, base packages, user, GRUB, autologin
# Also variables from base script are available
source ./arch_install_base.sh

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
    source "$GUI_PARSES_SCRIPT"

    if GUI_PACKAGES=$(parse_packages "$DESKTOP_ENV" "$GUI_PACKAGES_FILE"); then
        pacstrap /mnt $GUI_PACKAGES --needed
        arch-chroot /mnt systemctl enable sddm
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

echo "Normal installation complete. Remove ISO and reboot manually."
