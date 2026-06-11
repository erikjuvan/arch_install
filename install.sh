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

        # Configure default GUI keyboard repeat and display resolution
        arch-chroot /mnt bash <<'X11_DEFAULTS_EOF'
set -e

mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard-rate.conf <<'EOC'
Section "ServerFlags"
    Option "AutoRepeat" "200 40"
EndSection
EOC

touch /etc/xprofile
if ! grep -q "arch_install GUI defaults" /etc/xprofile; then
    cat >> /etc/xprofile <<'EOC'

# arch_install GUI defaults
if command -v xset >/dev/null 2>&1; then
    xset r rate 200 40
fi

if command -v xrandr >/dev/null 2>&1; then
    output="$(xrandr | awk '/ connected primary/{print $1; exit} / connected/{print $1; exit}')"
    if [ -n "$output" ]; then
        xrandr --output "$output" --mode 1920x1080 2>/dev/null || true
    fi
fi
EOC
fi
X11_DEFAULTS_EOF

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
