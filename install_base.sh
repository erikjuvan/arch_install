#!/usr/bin/env bash
set -euo pipefail # exit on errors, treat unset variables as errors, fail if any command in a pipeline fails
set -x # Print commands as they are executed
trap 'echo "Error on line $LINENO"; exit 1' ERR
exec > >(tee "install_base.log") 2>&1 # Redirect all commands to file

echo "=========================="
echo "Base installation started."
echo "=========================="
echo

# --------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------
CORE_INSTALLER_SCRIPT=install_core.sh
BASE_PACKAGES_FILE="packages_base.txt"
DOTFILES_REPO="https://github.com/erikjuvan/dotfiles"

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
# INSTALL BASE PACKAGES - setup my base of work
# --------------------------------------------------------------
pacstrap -K /mnt $(sed -E 's/#.*//; /^\s*$/d' "$BASE_PACKAGES_FILE") --needed

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

mkdir -p "/home/$USERNAME/.config/fish"
ln -sf "\$DOTDIR/.config/fish/config.fish" "/home/$USERNAME/.config/fish/config.fish"

ln -sf "\$DOTDIR/.config/nvim" "/home/$USERNAME/.config/nvim" || true
EOF

# --------------------------------------------------------------
# USE FISH AS THE NEW DEFAULT SHELL IF FISH INSTALLED
# --------------------------------------------------------------
arch-chroot /mnt bash <<EOF
# --- Set fish as shell if installed ---
if command -v /usr/bin/fish >/dev/null 2>&1; then
    grep -qxF '/usr/bin/fish' /etc/shells || echo '/usr/bin/fish' >> /etc/shells
    usermod -s /usr/bin/fish $USERNAME
fi
EOF

# --------------------------------------------------------------
# FINALIZE
# --------------------------------------------------------------
echo "==========================="
echo "Base installation complete."
echo "==========================="
echo

cp install_base.log "/mnt/home/$USERNAME/"

umount -R /mnt || true
