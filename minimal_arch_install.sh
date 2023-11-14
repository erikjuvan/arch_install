#!/bin/bash

# Redirect all commands to file
exec > >(tee "install.log") >&1

# Wipe drive and perform clean base install?
read -n 1 -r -p "Wipe drive and perform clean base install [y/N]? "
echo # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

	# Print commands as they are executed
	set -x

	# Base install
	umount -R /mnt 2> /dev/null
	wipefs -a /dev/sda
	echo 'type=83' | sfdisk /dev/sda
	yes | mkfs.ext4 /dev/sda1
	mount /dev/sda1 /mnt
	pacstrap -K /mnt base linux
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
	read -p "Add user: " user
	echo "Enter password for $user: "
	arch-chroot /mnt /bin/bash -c "useradd -m -s /bin/bash $user"
	arch-chroot /mnt /bin/bash -c "passwd $user"
	# Base install finished...
	echo "Minimal install finished."
	echo

	# Install grub?
	read -n 1 -r -p "Install grub [y/N]? "
	echo # move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		pacstrap /mnt grub
		# Setup grub
		arch-chroot /mnt /bin/bash -c "grub-install --target=i386-pc /dev/sda"
		arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
	fi

	# Install dhcpcd?
	read -n 1 -r -p "Install dhcpcd [y/N]? "
	echo # move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		pacstrap /mnt dhcpcd
		# Enable dhcpcd
		arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd"	
	fi

	# Install sudo?
	read -n 1 -r -p "Install sudo [y/N]? "
	echo # move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		pacstrap /mnt sudo
		# Add user to sudoers
		arch-chroot /mnt /bin/bash -c "sed -i 's/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$user ALL=(ALL:ALL) ALL/' /etc/sudoers"
	fi

	# Install fish?
	read -n 1 -r -p "Install fish [y/N]? "
	echo # move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		pacstrap /mnt fish
		# Change user shell to fish
		arch-chroot /mnt /bin/bash -c "chsh -s /bin/fish $user"
	fi

	# Install neovim?
	read -n 1 -r -p "Install neovim [y/N]? "
	echo # move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		pacstrap /mnt neovim
	fi

	# Disable printing of commands, since these next ones are too verbose
	set +x

fi

# Install additional packages?
read -n 1 -r -p "Install additional packages [y/N]? "
echo # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

	# Mount, in case we skipped the base install
	mount /dev/sda1 /mnt 2> /dev/null

	read -n 1 -r -p "eza htop mlocate ncdu openssh broot ranger nnn strace ltrace lsof fzf fd man-db tldr less the_silver_searcher [y/N]? " eza
	echo # move to a new line
	read -n 1 -r -p "gcc cmake git make base-devel [y/N]? " gcc
	echo # move to a new line
	read -n 1 -r -p "python python-pip python-setuptools [y/N]? " python
	echo # move to a new line
	read -n 1 -r -p "xorg-server xorg-xinit xorg-xset ttf-dejavu alacritty [y/N]? " xorg
	echo # move to a new line
	read -n 1 -r -p "i3 rofi [y/N]? " i3
	echo # move to a new line
	read -n 1 -r -p "xfce4 [y/N]? " xfce4
	echo # move to a new line
	read -n 1 -r -p "openbox obconf [y/N]? " openbox
	echo # move to a new line
	read -n 1 -r -p "lightdm [y/N]? " lightdm
	echo # move to a new line
	read -n 1 -r -p "chromium [y/N]? " chromium
	echo # move to a new line
	
	if [[ $eza =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed eza htop mlocate ncdu openssh broot ranger nnn strace ltrace lsof fzf fd man-db tldr less the_silver_searcher
	fi
	if [[ $gcc =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed gcc cmake git make base-devel
	fi
	if [[ $python =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed python python-pip python-setuptools
	fi
	if [[ $xorg =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed xorg-server xorg-xinit xorg-xset ttf-dejavu alacritty
	fi
	if [[ $i3 =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed i3 rofi
	fi
	if [[ $xfce4 =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed xfce4
	fi
	if [[ $openbox =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed openbox obconf
	fi
	if [[ $lightdm =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed lightdm-gtk-greeter
	fi
	if [[ $chromium =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed chromium
	fi
	
fi

umount -R /mnt 2> /dev/null

# Finished
echo "Done."
