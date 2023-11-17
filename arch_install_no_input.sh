#!/bin/bash

# Redirect all commands to file
exec > >(tee "install.log") >&1

# Print commands as they are executed
set -x

hostname=arch
username=erik

##############
# Disk setup #
##############
umount -R /mnt 2> /dev/null
wipefs -a /dev/sda
echo 'type=83' | sfdisk /dev/sda
yes | mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt

####################
# Install packages #
####################
# Install base system
pacstrap -K /mnt base linux
# Install additional packages
sed 's/#.*//' packages.txt | xargs pacstrap /mnt --needed

####################
# Configure system #
####################
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Ljubljana /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
arch-chroot /mnt /bin/bash -c "sed -i 's/#en_US.UTF/en_US.UTF/' /etc/locale.gen"
arch-chroot /mnt /bin/bash -c "locale-gen"
arch-chroot /mnt /bin/bash -c "echo 'LANG=en_US.UTF-8' > /etc/locale.conf"
# Add hostname
arch-chroot /mnt /bin/bash -c "echo $hostname > /etc/hostname"
# Root password
arch-chroot /mnt /bin/bash -c "usermod --password='$(echo aa | openssl passwd -1 -stdin)' root"
# Add new user
arch-chroot /mnt /bin/bash -c "useradd -m -s /usr/bin/fish -G sys,wheel,users,adm,log $username"
arch-chroot /mnt /bin/bash -c "usermod --password='$(echo aa | openssl passwd -1 -stdin)' $username"
# Give user sudo privileges
arch-chroot /mnt /bin/bash -c "sed -i \"s/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$username ALL=(ALL:ALL) NOPASSWD: ALL/\" /etc/sudoers"
# Enable dhcpcd
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"
# Setup grub
arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc /dev/sda"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
# Autologin
arch-chroot /mnt /bin/bash -c "mkdir -p /etc/systemd/system/getty@tty1.service.d/"
arch-chroot /mnt /bin/bash -c "echo \"[Service]\" > /etc/systemd/system/getty@tty1.service.d/autologin.conf"
arch-chroot /mnt /bin/bash -c "echo \"ExecStart=\" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
arch-chroot /mnt /bin/bash -c "echo \"ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\u' --noclear --autologin $username %I \\\$TERM\" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf"
# Deploy my github dotfiles
arch-chroot /mnt sudo -u $username /bin/bash -c "git clone https://github.com/erikjuvan/dotfiles ~/.dotfiles"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.xinitrc ~"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.xprofile ~"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.gitconfig ~"
arch-chroot /mnt sudo -u $username /bin/bash -c "mkdir -p ~/.config/alacritty"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.config/alacritty/alacritty.yml ~/.config/alacritty"
arch-chroot /mnt sudo -u $username /bin/bash -c "mkdir -p ~/.config/fish"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.config/fish/config.fish ~/.config/fish"
arch-chroot /mnt sudo -u $username /bin/bash -c "ln -sf ~/.dotfiles/.config/nvim ~/.config/"
# Copy install log to user directory
cp install.log /mnt/home/$username
# Unmount
umount -R /mnt 2> /dev/null
# Eject CD rom TODO
# eject -r -m # This doesn't work. I don't know how to do this without crashing the install.
# Reboot TODO
# reboot # don't reboot since we can't eject CD rom
# Finished
echo "Done."