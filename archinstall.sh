#!/usr/bin/env bash

loadkeys sv-latin1
timedatectl set-timezone Europe/Stockholm
timedatectl set-ntp true

function set_password {
    read -rs -p 'password: ' rootPassword
    echo -ne '\n'
    read -rs -p 'confirm password: ' rootPassword2
    echo -ne '\n'

    if [ $rootPassword != $rootPassword2 ]; then
        echo "Passwords do not match!"
        set_password
    fi
}

read -p 'Are you sure you want to continue? [y/N]' wipeWarning
if [ $wipeWarning != "y" ]; then
    echo 'aborted'
    exit 1
fi

echo 'starting full install!'
read -p 'username: ' username
set_password
read -p 'boot disk: ' bootDrive
read -p 'hostname: ' hostname

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Unmount, Delete, and create new partitions
# 1. Boot
# 2. Swap
# 3. Root
# root is created last so we grab the remaining space of the disk
umount -R /mnt
swapoff -a 
sfdisk --delete $bootDrive
echo -e 'size=1G, type=U\n size=8G, type=S\n size=+, type=L\n' | sfdisk $bootDrive

# nvme partition names differ from other drives 
if [[ $bootDrive == *"nvme"* ]]; then
    bootDrive=$bootDrive"p" 
fi

# Format partitions
# Append partition number resulting in /dev/sda1 or /dev/nvme0n1p1
mkfs.fat -F 32 $bootDrive"1" # Boot
mkswap $bootDrive"2" # Swap
mkfs.ext4 $bootDrive"3" # Root

# Mount drives
mount $bootDrive"3" /mnt
mount --mkdir $bootDrive"1" /mnt/boot
swapon $bootDrive"2"

# Install base packages required for the system including video drivers(AMD only)
pacstrap /mnt base linux-zen dhcpcd iwd sudo man-db man-pages texinfo base-devel git refind linux-firmware amd-ucode \
              mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon lib32-libva-mesa-driver xf86-video-amdgpu

# Generate fstab to automatically mount drives when booting the actual system
genfstab -U /mnt > /mnt/etc/fstab

# Generate system files
echo -e "LANG=en_US.UTF-8
LC_MESSAGES=en_US.UTF-8
LC_NUMERIC=sv_SE.UTF-8
LC_TIME=sv_SE.UTF-8
LC_MONETARY=sv_SE.UTF-8
LC_PAPER=sv_SE.UTF-8
LC_NAME=sv_SE.UTF-8
LC_ADDRESS=sv_SE.UTF-8
LC_TELEPHONE=sv_SE.UTF-8
LC_MEASUREMENT=sv_SE.UTF-8
LC_IDENTIFICATION=sv_SE.UTF-8" > /mnt/etc/locale.conf

echo "KEYMAP=sv-latin1" > /mnt/etc/vconsole.conf
echo "$hostname" > /mnt/etc/hostname

# Uncomment needed lines in configuration files
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /mnt/etc/pacman.conf
sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
sed -i 's/^#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /mnt/etc/locale.gen

# Chroot into system, set locales & timezone, create user account & install refind
arch-chroot /mnt /bin/bash <<END
    ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime &&
    hwclock --systohc &&
    locale-gen &&
    mkinitcpio -P &&
    useradd $username -m -s /bin/bash -U -G wheel -p $rootPassword &&
    echo $rootPassword | passwd $username --stdin &&
    passwd -l root &&
    refind-install &&
    pacman -Syu --noconfirm --needed &&
    systemctl enable iwd
    systemctl enable dhcpcd
    exit
END

# Setup refind-linux.conf
rootPartition=$bootDrive"3"
rootUUID=$(sudo blkid -s UUID -o value $rootPartition)
rm /mnt/boot/refind_linux.conf
echo -e '"Boot with standard options"  "ro root=UUID='$rootUUID'"\n"Boot to single-user mode"    "ro root=UUID='$rootUUID'   single"\n"Boot with minimal options"   "ro root=UUID='$rootUUID'"' > /mnt/boot/refind_linux.conf

# Unmount and exit script
umount -R /mnt
swapoff -a 

echo 'Install finished! please reboot and remove install media!'
exit 1
