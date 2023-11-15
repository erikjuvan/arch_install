#!/bin/bash

# Redirect all commands to file
exec > >(tee "install.log") >&1

# Wipe drive and perform clean base install?
read -n 1 -r -p "Wipe drive and perform clean base install [y/N]? "
echo # move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Print commands as they are executed
set -x

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
pacstrap -K /mnt base linux linux-firmware grub dhcpcd sudo neovim

####################
# Configure system #
####################
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Ljubljana /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
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
read -p "Add user: " username
echo "Enter password for $username: "
arch-chroot /mnt /bin/bash -c "useradd -m -s /bin/bash $username"
arch-chroot /mnt /bin/bash -c "passwd $username"
# Setup grub
arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc /dev/sda"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
# Enable dhcpcd
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"	
# Add user to sudoers
arch-chroot /mnt /bin/bash -c "sed -i 's/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$username ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers"
# Install fish?
read -n 1 -r -p "Install fish [y/N]? "
echo # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    pacstrap /mnt fish
    # Change user shell to fish
    arch-chroot /mnt /bin/bash -c "chsh -s /usr/bin/fish $username"
fi
# Copy install log to user directory
cp install.log /mnt/home/$username
# Unmount
umount -R /mnt 2> /dev/null
# Finished
echo "Done."
