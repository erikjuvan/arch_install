#!/bin/bash

# print commands as they are executed
set -x

umount -R /mnt1
wipefs -a /dev/sda
echo 'type=83' | sfdisk /dev/sda
yes | mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
pacstrap -K /mnt base linux grub dhcpcd sudo fish vim

echo "Install htop+extras?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) pacstrap /mnt htop strace lsof; break;;
        No ) break;;
    esac
done

echo "Install python?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) pacstrap /mnt python python-pip python-setuptools; break;;
        No ) break;;
    esac
done

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "pacman -Syy"
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Region/City /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
arch-chroot /mnt /bin/bash -c "sed -i 's/#en_US.UTF/en_US.UTF/' /etc/locale.gen"
arch-chroot /mnt /bin/bash -c "locale-gen"
arch-chroot /mnt /bin/bash -c "echo 'LANG=en_US.UTF-8' > /etc/locale.conf"
arch-chroot /mnt /bin/bash -c "echo 'arch' > /etc/hostname"
arch-chroot /mnt /bin/bash -c "passwd"
arch-chroot /mnt /bin/bash -c "useradd -m -s /bin/fish erik"
arch-chroot /mnt /bin/bash -c "passwd erik"
arch-chroot /mnt /bin/bash -c "sed -i 's/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\nerik ALL=(ALL:ALL) ALL/' /etc/sudoers"
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"
arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc /dev/sda"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
umount -R /mnt 