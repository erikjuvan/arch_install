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
pacstrap -K /mnt base linux grub dhcpcd sudo fish

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
# Copy install log to user directory
cp install.log /mnt/home/$username
# Unmount
umount -R /mnt 2> /dev/null
# Finished
echo "Done."
