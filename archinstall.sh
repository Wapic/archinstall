loadkeys sv-latin1
timedatectl set-timezone Europe/Stockholm
timedatectl set-ntp true

echo 'keymap and timedate set'
read -p '[exit, partition, mount, chroot, root, user, FULL] ' continue
if [ $continue == "exit" ]; then
    echo 'exiting...'
    exit 1
fi

if [ $continue == "FULL" ]; then
    read -p 'Are you sure you want to continue? [y/N]' wipeWarning
    if [ $wipeWarning != "y" ]; then
        echo 'aborting...'
        exit 1
    fi

    echo 'starting full install!'
    read -p 'username: ' username
    read -rs -p 'password: ' rootPassword
    echo -ne '\n'
    read -rs -p 'confirm password: ' rootPassword2
    echo -ne '\n'
    read -p 'is vm? [y/N]' isVM
    read -p 'boot disk: ' bootDrive
    read -p 'hostname: ' hostname
    read -p 'gpu? [AMD/nvidia]' gpuDriver
    
    if [ $rootPassword != $rootPassword2 ]; then
        echo 'passwords do not match!'
        exit 1
    fi

    nvme=false
    if [[ $bootDrive == *"nvme"* ]]; then
        nvme=true
    fi
    
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    # Delete and create new partitions
    umount -R /mnt
    swapoff -a 
    sfdisk --delete $bootDrive
    echo -e 'size=1G, type=U\n size=8G, type=S\n size=+, type=L\n' | sfdisk $bootDrive
    
    # nvme partition names differ from other drives 
    if [ $nvme == true ]; then
        bootDrive=$bootDrive"p" 
    fi

    # Formatting
    mkfs.fat -F 32 $bootDrive"1" # /dev/sda1 or /dev/nvme0n1p1
    mkswap $bootDrive"2"
    mkfs.ext4 $bootDrive"3"

    # Mount drives
    mount $bootDrive"3" /mnt
    mount --mkdir $bootDrive"1" /mnt/boot
    swapon $bootDrive"2"

    #Install base packages
    pacstrap /mnt base linux-zen dhcpcd iwd neovim vim sudo man-db man-pages texinfo base-devel refind
    if [ $isVM == "y" ]; then
        pacstrap /mnt intel-ucode qemu-guest-agent lemurs hyprland openssh kitty git zip unzip
    else 
        pacstrap /mnt linux-firmware amd-ucode lemurs hyprland wireplumber pipewire pipewire-alsa pipewire-pulse pipewire-audio pcmanfm playerctl fastfetch firefox kitty git openssh zip unzip jdk8-openjdk jdk21-openjdk dunst libnotify wofi waybar hyprpicker hyprlock hyprpaper hypridle imv wl-clipboard slurp grim qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk btop zsh fzf nautilus gnome-keyring nextcloud-client bat glxinfo
    fi
    
    if [ $isVM != "y" ]; then 
        if [ $gpuDriver == "nvidia" ]; then
            pacstrap /mnt nvidia-dkms nvidia-settings lib32-nvidia-utils
        else
            pacstrap /mnt mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau
        fi
    fi

    genfstab -U /mnt > /mnt/etc/fstab
    arch-chroot /mnt /bin/bash <<END
        ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime &&
        hwclock --systohc &&
        sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen &&
        locale-gen &&
        echo LANG=en_US.UTF-8 > /etc/locale.conf &&
        echo KEYMAP=sv-latin1 > /etc/vconsole.conf && 
        echo $hostname > /etc/hostname &&
        mkinitcpio -P &&
        useradd $username -m -s /bin/bash -U -G wheel -p $rootPassword &&
        echo $rootPassword | passwd $username --stdin &&
        passwd -l root &&
        refind-install &&
        rm /boot/refind_linux.conf &&
        sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf &&
        sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf &&
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers &&
        pacman -Syu --noconfirm --needed &&
        cd /home/$username/ &&
        git clone https://aur.archlinux.org/yay.git/ &&
        cd yay &&
        makepkg -si &&
        exit
END
    rootPartition=$bootDrive"3"
    rootUUID=$(sudo blkid $rootPartition | grep -Eo "UUID=\".{36}\"\s" | grep -Eo ".{36}\b")
    echo -e '"Boot with standard options"  "ro root=UUID='$rootUUID'"\n"Boot to single-user mode"    "ro root=UUID='$rootUUID'   single"\n"Boot with minimal options"   "ro root=UUID='$rootUUID'"' > /mnt/boot/refind_linux.conf
    umount -R /mnt
    swapoff -a 
    echo 'Install finished! please reboot and remove install media!'
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
    pacstrap /mnt base linux-zen linux-firmware dhcpcd iwd neovim vim sudo
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
    useradd $username -m -G wheel
    echo 'Password: '
    passwd $username
    echo 'Finished! login to new user and run user script. remember to uncomment %wheel using visudo!'
    cp ./archinstall.sh /home/$username/
fi

if [ $continue == "user" ]; then
    read -p 'What gpu driver? [amd/nvidia]' gpuDriver
   
    if [ $gpuDriver == "amd" ]; then
        pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver
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
    
    pacman -S lemurs wayland hyprland wofi waybar swaybg swayimg wl-clipboard slurp grim qt5-wayland qt6-wayland xdg-desktop-portal-hyprland
    echo -e '#! /bin/sh\nexec Hyprland' > /etc/lemurs/wayland/hyprland
    chmod 755 /etc/lemurs/wayland/hyprland

    read -p 'Install brightness control? [Y/N]' brtnessctl
    if [ $brtnessctl == "Y" -o $brtnessctl == "y" ]; then
        pacman -S brightnessctl
    fi

    echo 'installing essentials...'
    pacman -S wireplumber pipewire pipewire-alsa pipewire-pulse pipewire-audio pcmanfm playerctl fastfetch firefox kitty base-devel git openssh zip unzip jdk8-openjdk jdk21-openjdk dunst libnotify

    read -p 'install yay? [Y/N]' yay
    if [ $yay == "Y" -o $yay == "y" ]; then
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
    fi

    echo 'Script all finished! time to reboot!'
fi
