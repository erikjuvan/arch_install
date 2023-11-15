#!/bin/bash

# This script is set up to install linux on uefi system using sda1 as efi partition, sda2 as /, sda3 as swap, sdb1 as /home

# Redirect all commands to file
exec > >(tee "install.log") >&1

# Wipe drive and perform clean base install?
read -n 1 -r -p "Wipe drive and perform clean install [y/N]? "
echo # move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Print commands as they are executed
set -x

timedatectl set-ntp true

##############
# Disk setup #
##############
umount -R /mnt 2> /dev/null
wipefs -a /dev/sda

# Define the disk
disk="/dev/sda"  # Change X to the appropriate letter for your disk
# Create GPT partition table
sudo parted -s $disk mklabel gpt
# Create the first partition (300MB, FAT32)
sudo parted -s $disk "mkpart primary fat32 1MiB 301MiB"
sudo parted -s $disk "set 1 esp on"
# Create the second partition (remaining space - 10GB, ext4)
sudo parted -s $disk "mkpart primary ext4 301MiB -10GiB"
# Create the third partition (10GB, linux swap)
sudo parted -s $disk "mkpart primary linux-swap -10GiB 100%"

# Make filesystems
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3

# Mount /
mount /dev/sda2 /mnt

# Mount /boot/efi
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

# Mount /home
mkdir -p /mnt/home
mount /dev/sdb1 /mnt/home

# Swap
swapon /dev/sda3

####################
# Install packages #
####################
pacstrap -K /mnt base linux linux-firmware fish

# Install aditional packages
pacstrap /mnt dhcpcd sudo grub neovim
pacstrap /mnt openssh man-db tldr less htop eza mlocate ncdu broot ranger fzf fd the_silver_searcher strace ltrace lsof
pacstrap /mnt base-devel gcc cmake git lazygit make python python-pip python-setuptools
pacstrap /mnt xorg-server xorg-xinit xorg-xset ttf-dejavu alacritty i3 rofi
pacstrap /mnt chromium unrar unzip wget

pacstrap /mnt openbox obconf lightdm lightdm-gtk-greeter xf86-video-amdgpu pulseaudio mesa
pacstrap /mnt iwd wpa_supplicant networkmanager
pacstrap /mnt efibootmgr os-prober

# Notable mentions
# dmenu

####################
# Configure system #
####################
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Ljubljana /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc --utc"
arch-chroot /mnt /bin/bash -c "sed -i 's/#en_US.UTF/en_US.UTF/' /etc/locale.gen"
arch-chroot /mnt /bin/bash -c "locale-gen"
arch-chroot /mnt /bin/bash -c "echo 'LANG=en_US.UTF-8' > /etc/locale.conf"
# Add hostname...
read -p "Hostname: " hostname
arch-chroot /mnt /bin/bash -c "echo $hostname > /etc/hostname"
# Root password
echo "Enter password for root: "
arch-chroot /mnt /bin/bash -c "passwd"
# Add new user...
read -p "Add user: " user
echo "Enter password for $user: "
arch-chroot /mnt /bin/bash -c "useradd -m -s /usr/bin/fish -G sys,wheel,users,adm,log $user"
arch-chroot /mnt /bin/bash -c "passwd $user"
# Give user sudo privileges
arch-chroot /mnt /bin/bash -c "sed -i 's/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$user ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers"
# Enable dhcpcd
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"
# Setup grub for EFI
arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot/efi"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
# Create xinitrc and xprofile
arch-chroot /mnt /bin/bash -c "printf '[ -f /etc/xprofile ] && . /etc/xprofile\n[ -f ~/.xprofile ] && . ~/.xprofile\n\n#exec i3 -V -d all >~/i3log 2>&1\nexec i3\n#exec openbox' > /home/$user/.xinitrc"
arch-chroot /mnt /bin/bash -c "printf 'xset r rate 230 30\nsetxkbmap -option caps:escape' > /home/$user/.xprofile"
# Autologin
arch-chroot /mnt /bin/bash -c "mkdir -p /etc/systemd/system/getty@tty1.service.d/"
arch-chroot /mnt /bin/bash -c "echo \"[Service]\" > /etc/systemd/system/getty@tty1.service.d/autologin.conf"
arch-chroot /mnt /bin/bash -c "echo \"ExecStart=\" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
arch-chroot /mnt /bin/bash -c "echo \"ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\u' --noclear --autologin $username %I \\\$TERM\" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
# Copy install log to user directory
cp install.log /mnt/home/$username
# Unmount
umount -R /mnt 2> /dev/null
# Finished
echo "Done."
