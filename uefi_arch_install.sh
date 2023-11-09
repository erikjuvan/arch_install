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

    timedatectl set-ntp true
    
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
    
    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 /dev/sda2
    
	mount /dev/sda2 /mnt
    mkdir -p /mnt/boot/efi
    mkdir -p /mnt/home
    
    mount /dev/sda1 /mnt/boot/efi
    mount /dev/sdb1 /mnt/home
    
    mkswap /dev/sda3
    swapon /dev/sda3
    
	pacstrap -K /mnt base base-devel linux linux-firmware iw iwd dhcpcd sudo fish neovim grub efibootmgr os-prober
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

    arch-chroot /mnt /bin/bash -c "sed -i 's/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL\n$user ALL=(ALL:ALL) ALL/' /etc/sudoers"

    # Setup grub
    arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot/efi"
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"

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

	read -n 1 -r -p "exa htop mlocate ncdu openssh broot ranger nnn strace ltrace lsof [y/N]? " exa
	echo # move to a new line
	read -n 1 -r -p "gcc cmake git make base-devel [y/N]? " gcc
	echo # move to a new line
	read -n 1 -r -p "python python-pip python-setuptools [y/N]? " python
	echo # move to a new line
	read -n 1 -r -p "xorg-server xorg-xinit xorg-xset ttf-dejavu alacritty [y/N]? " xorg
	echo # move to a new line
	read -n 1 -r -p "i3 [y/N]? " i3
	echo # move to a new line
	read -n 1 -r -p "xfce4 [y/N]? " xfce4
	echo # move to a new line
	read -n 1 -r -p "openbox obconf [y/N]? " openbox
	echo # move to a new line
	read -n 1 -r -p "lightdm [y/N]? " lightdm
	echo # move to a new line
	read -n 1 -r -p "chromium [y/N]? " chromium
	echo # move to a new line
	
	if [[ $exa =~ ^[Yy]$ ]]
	then
		pacstrap /mnt --needed exa htop mlocate ncdu openssh broot ranger nnn strace ltrace lsof
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
		pacstrap /mnt --needed i3
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
