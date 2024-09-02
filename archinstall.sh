loadkeys sv-latin1
timedatectl set-ntp true

echo "keymap and timedate set"
read -p '[exit, partition, mount, chroot, root, user] ' continue
if [ $continue == "exit" ]; then
    echo 'exiting...'
    exit 1
fi

if [ $continue == "partition" ]; then
    echo 'partitioning disks...'
    read -p "boot disk: " bootDrive
    read -p "ALL DATA WILL BE DELETED! continue? [Y/N]" wipeWarning
    if [ $wipeWarning != "Y" ]; then
	echo 'aborting...'
	exit 1
    fi
    sfdisk --delete $bootDrive
    echo -e 'size=1G, type=U\n size=16G, type=S\n size=+, type=L\n' | sfdisk $bootDrive
fi

if [ $continue == "mount" ]; then
    read -p 'root partition: ' rootPartition
    mkfs.ext4 $rootPartition

    read -p 'swap partition: ' swap
    mkswap $swap

    read -p 'efi partition: ' efi
    mkfs.fat -F 32 $efi

    mount $rootPartition /mnt
    mount --mkdir $efi /mnt/boot
    swapon $swap
    pacstrap /mnt base linux linux-firmware dhcpcd iwd neovim vi sudo
    genfstab -U /mnt > /mnt/etc/fstab
    cp ./archinstall.sh /mnt/archinstall.sh
    echo 'SCRIPT FINISHED chroot into /mnt and run script again'
    exit 1
fi

if [ $continue == "chroot" ]; then
    echo 'Setting locales...'
    ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
    hwclock --systohc
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    echo 'KEYMAP=sv-latin1' > /etc/vconsole.conf
    
    read -p 'hostname: ' hostname
    echo $hostname > /etc/hostname
    
    echo 'mkinitcpio...'
    mkinitcpio -P
    
    echo 'Setting root password!'
    passwd

    echo 'Installing GRUB...'
    pacman -S grub efibootmgr os-prober
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    echo 'Finished! exit chroot and reboot into system and run root script while logged in as root!'
   exit 1
fi

if [ $continue == "root" ]; then   
    echo 'Creating user...'
    read -p 'Username: ' username
    useradd $username -m
    echo 'Password: '
    passwd $username
    echo 'Adding user to group: wheel'
    usermod -aG wheel $username
    echo 'Finished! login to new user and run user script. remember to uncomment %wheel using visudo!'
    cp ./archinstall.sh /home/$username/
fi

if [ $continue == "user" ]; then
    read -p 'What gpu driver? [amd/nvidia]' gpuDriver
   
    if [ $gpuDriver == "amd" ]; then
        echo 'not yet implemented'
    fi
   
    if [ $gpuDriver == "nvidia" ]; then
        echo 'installing Nvidia Drivers...'
        read -p 'open? (rtx 20 series and newer) [Y/N]' gpuArch
        if [ $gpuArch == "N" ]; then
            pacman -S nvidia nvidia-settings
        fi
        if [ $gpuArch == "Y" ]; then
            pacman -S nvidia-open nvidia-settings
        fi
    fi
    
    echo 'installing login manager...'
    pacman -S lemurs

    read -p 'Display server? [x/wayland]' displayServer
    if [ $displayServer == "x" -o $displayServer == "xorg" ]; then
        pacman -S xorg i3-wm rofi polybar feh xclip dunst
    fi
    
    if [ $displayServer == "wayland" ]; then
        pacman -S wayland hyprland wofi waybar swaybg swayimg wl-clipboard mako slurp grime
        echo -e '#! /bin/sh\nexec Hyprland' > /etc/lemurs/wayland/hyprland
        chmod 755 /etc/lemurs/wayland/hyprland
    fi

    echo 'installing essentials...'
    pacman -S pipewire pcmanfm playerctl neofetch firefox kitty base-devel git openssh zip unzip jdk8-openjdk

    read -p 'install yay? [Y/N]' yay
    if [ $yay == "Y" -o $yay == "y" ]; then
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
    fi

    echo 'Script all finished! time to reboot!'
fi
