#!/bin/bash
set -euo pipefail # exit on errors, treat unset variables as errors, fail if any command in a pipeline fails
set -x # Print commands as they are executed
trap 'echo "Error on line $LINENO"; exit 1' ERR
exec > >(tee "install_core.log") 2>&1 # Redirect all commands to file

echo "==========================="
echo "Core installation started."
echo "==========================="
echo

# --------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------
HOSTNAME="arch"
USERNAME="erik"
PASSWORD="aa"
DISK="/dev/sda"
PARTITION="${DISK}1"
TIMEZONE="Europe/Ljubljana"
LOCALE="en_US.UTF-8"
CORE_PACKAGES_FILE="packages_core.txt"

# --------------------------------------------------------------
# SAFETY CHECK
# --------------------------------------------------------------
if [[ ! -d /run/archiso ]]; then
    echo "WARNING: You are not running from the Arch ISO environment!"
    echo "Only continue if you KNOW what you're doing."
fi

echo
echo "This script will DESTROY data on $DISK"
echo "This is destructive and CANNOT be undone."

read -rp "Type YES (all caps) to continue: " confirm

if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# --------------------------------------------------------------
# DISK SETUP (BIOS-style MBR, single ext4 partition)
# --------------------------------------------------------------
umount -R /mnt 2>/dev/null || true
wipefs -a "$DISK"

sfdisk "$DISK" <<EOF
label: dos
unit: sectors
1 : type=83
EOF

mkfs.ext4 -F ${PARTITION}
mount ${PARTITION} /mnt

# --------------------------------------------------------------
# CORE INSTALL
# --------------------------------------------------------------
# For faster mirrors
reflector --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

# Core install
pacstrap -K /mnt $(sed -E 's/#.*//; /^\s*$/d' "$CORE_PACKAGES_FILE") --needed

# Copy mirrorlist to installed system
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# Generate file system table
genfstab -U /mnt >> /mnt/etc/fstab

# --------------------------------------------------------------
# CONFIGURATION IN CHROOT
# --------------------------------------------------------------
arch-chroot /mnt bash <<EOF
set -e

# Time / locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Root password
echo "root:$PASSWORD" | chpasswd

# User + sudo
useradd -m -s /usr/bin/bash -G wheel,sys,adm,log,users "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Sudo: user gets passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-$USERNAME
chmod 440 /etc/sudoers.d/99-$USERNAME

# Network
systemctl enable dhcpcd || true

# Bootloader
grub-install --target=i386-pc "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

# Autologin on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOA
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOA

EOF

# --------------------------------------------------------------
# COPY LOG + CLEANUP
# --------------------------------------------------------------
cp install_core.log "/mnt/home/$USERNAME"/
umount -R /mnt || true

echo
echo "==========================="
echo "Core installation complete."
echo "==========================="
echo