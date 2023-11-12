#!/bin/bash

# Redirect all commands to file
exec > >(tee "install.log") >&1

# Print commands as they are executed
set -x

hostname=arch
username=erik

# Base install
umount -R /mnt 2> /dev/null
wipefs -a /dev/sda
echo 'type=83' | sfdisk /dev/sda
yes | mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
pacstrap -K /mnt base linux fish
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Ljubljana /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
arch-chroot /mnt /bin/bash -c "sed -i 's/#en_US.UTF/en_US.UTF/' /etc/locale.gen"
arch-chroot /mnt /bin/bash -c "locale-gen"
arch-chroot /mnt /bin/bash -c "echo 'LANG=en_US.UTF-8' > /etc/locale.conf"
# Add hostname...
arch-chroot /mnt /bin/bash -c "echo $hostname > /etc/hostname"
# Root password
arch-chroot /mnt /bin/bash -c "usermod --password=$(echo aa | openssl passwd -1 -stdin) root"
# Add new user...
arch-chroot /mnt /bin/bash -c "useradd -m -s /usr/bin/fish $username"
arch-chroot /mnt /bin/bash -c "usermod --password=$(echo aa | openssl passwd -1 -stdin) $username"

pacstrap /mnt grub
arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc /dev/sda"
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"

pacstrap /mnt dhcpcd
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"

pacstrap /mnt sudo
arch-chroot /mnt /bin/bash -c "sed -i \"s/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$username ALL=(ALL:ALL) NOPASSWD: ALL/\" /etc/sudoers"

pacstrap /mnt neovim
pacstrap /mnt --needed exa htop mlocate ncdu openssh broot ranger nnn fd fzf openssh man-db less base-devel git make xorg-server xorg-xinit xorg-xset ttf-dejavu alacritty i3 rofi chromium

# Create xinitrc and xprofile
arch-chroot /mnt /bin/bash -c "printf '[ -f /etc/xprofile ] && . /etc/xprofile\n[ -f ~/.xprofile ] && . ~/.xprofile\n\n#exec i3 -V -d all >~/i3log 2>&1\nexec i3\n#exec openbox' > /home/$user/.xinitrc"
arch-chroot /mnt /bin/bash -c "printf 'xset r rate 230 30\nsetxkbmap -option caps:escape' > /home/$username/.xprofile"

# Autologin
arch-chroot /mnt /bin/bash -c "mkdir -p /etc/systemd/system/getty@tty1.service.d/"
arch-chroot /mnt /bin/bash -c "printf \"[Service]\nExecStart=\nExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $username %I \$TERM\" > /etc/systemd/system/getty@tty1.service.d/autologin.conf"

# Unmount
umount -R /mnt 2> /dev/null

# Eject CD rom
eject -r -m

# Reboot
reboot
