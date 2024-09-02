# archinstall
>[!CAUTION]
>Incorrect usage of this script can and most likely will result in unwanted loss of data!
>Use this script at your own risk!

Simple bash script made to make install process of arch easier when reinstalling for the 20th time.

# Usage:
### Download script:
```
curl https://raw.githubusercontent.com/Wapic/archinstall/main/archinstall.sh -o archinstall.sh
chmod +x archinstall.sh
```


### 1. Partition:
run `./archinstall.sh` and select `partition`

select a drive you wish to use as a boot drive
>[!CAUTION]
>***Any exisiting partitions will be deleted!***

the following partitions will be created on that drive:
```
/dev/sdX1: 1GB EFI Partition
/dev/sdX2: 16GB Swap Partiton
/dev/sdX3: Root partition of remaining space
```


### 2. Mount:
run `./archinstall.sh` and select `mount`  
enter the partitions we created in the previous step.  
it will then format and mount the drives.
```
/dev/sdX1: /mnt/boot
/dev/sdX2: SWAP
/dev/sdX3: /mnt
```
then base packages will be downloaded and fstab generated.  
once that is done you can run `arch-chroot /mnt` and move on to the next step.


### 3. Chroot:
run `./archinstall.sh` and select `chroot`

this will:  
1. set locale, keymap & timezone.
2. ask you to set your hostname.  
3. ask you set your root password.  
4. install grub as a bootloader.

now exit chroot `Ctrl+D` and `reboot`
>[!NOTE]
>Make sure to remove installation media!


### 4. Root:
login to `root` using the password you just set.  
run `./archinstall.sh` and select `root`  
enter your username and password for your user.  
run `visudo` and uncomment `#%wheel ALL=(ALL:ALL) ALL`  
`:wq` to save and exit visudo and then `logout`

### 5. User:
login to your new user.  
run `./archinstall.sh` and select `user`  
enter your GPU vendor to install GPU drivers.  
[Lemurs](https://github.com/coastalwhite/lemurs) will be installed as the login manager.  
select a display server (x-org / wayland).  
i3-wm or Hyprland and complementing packages will be installed.  
essential packages will be installed.  
select if you want to install [Yay](https://github.com/Jguer/yay).

### 6. Reboot!
and now you're done! simply reboot and start configuring!
