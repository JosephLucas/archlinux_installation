## Backup any data

### Backup a linux OS
(https://wiki.archlinux.org/index.php/Rsync#Full_system_backup)

Download a list of ignored folders and files
```bash
wget https://raw.githubusercontent.com/JosephLucas/archlinux_installation/master/ignored_during_backup
```

Start with a dry run with the option `--dry-run` to see what rsync plans to do.
```bash
rsync --dry-run -av --delete --stats --info=progress2 --exclude={"/path/to/backup/folder/*"} --exclude-from=ignored_during_backup / /path/to/backup/folder
```

NB: this will do backup the /boot, /etc and /home


### Backup home

### Backup a former windows partition
Tools to list disks on the machine
```bash
lsblk
lsblk -f
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,PARTLABEL
lskid
```
*ntfsresize* can resize windows partition (shrink or extend) without any previous defragmentation.
*ntfsclone* copies ntfs partitions fast.

Get how much space is *really* used before resizing the partition
```bash
ntfsresize --info
```
If exception is raised, like:

    disk has been scheduled for *chkdsk*
you may need to relaunch windows.
This will launch the *chkdsk* tool to repare some errors in the *ntfs* partition.

Finally, edit the ntfs partition, for instance
```bash
ntfsresize -s -o /mnt/depot_jo/Backup/windows.sepcial.img /dev/sdX
ntfsresize --no-action --size 100G /dev/sdaX
ntfsresize -v --size 100G /dev/sdaX
```


# Installation of Arch Linux
The installation process is for UEFI computers, we do not cover BIOS installation process. 

We rely heavily on: 
 * rEFInd bootloader
 * systemd arch linux
 * xfce4 DE
 * lightdm DM

Many steps are relative to a ASUS Zenbook Prime UX32VD machine.

Main inspirations:

    https://wiki.archlinux.org/index.php/installation_guide
    https://wiki.archlinux.org/index.php/General_recommendations
    https://wiki.archlinux.fr/installation
    https://wiki.archlinux.org/index.php/ASUS_Zenbook_Prime_UX31A

## Download the last iso of Arch Linux
Use a mirror listed at https://www.archlinux.org/download/

Being in France, I used https://arch.yourlabs.org/iso/2018.01.01/

## Create an Arch Linux live USB
Format your usb stick in fat32 (this will destroy your data)
```bash
mkfs.vfat -n <name_for_your_pendrive> -I /dev/sdc
```
With sdX the USB stick device
```bash
dd bs=4M if=arch.iso of=/dev/sdX status=progress
``` 

## Boot from the USB stick in EFI mod
After booting, Enter *root* as login.

At any time you can switch to another console by pressing `Alt + a lateral arrow`.

This can be useful to read a documentation while installing Arch Linux.

Read offline documentation
```bash
less ./install.txt
```

Set keyboard layout into french AZERTY
```bash
loadkeys fr-latin1
```
Verify that computer has booted in efi
```bash
efivar -l
```
output should be non-null.

## Connect to the internet
Two options: 
1. use your phone with usb tethering 
2. activate wifi

(first option is usually easier).

### 4G
1. Plug a 4G phone with USB tethering
2. exec `dhcpcd` to start a dhcp (Dynamic Host Configuration Protocol) client.

### Wifi
#### Using wifi-menu and netctl
```bash
wifi-menu
```
Give a (name) to the config and enter a password if needed. This writes a file in `/etc/netctl/<name>`.

Load this file
```bash
netctl start <name>
```
#### Using iw (if previous method is not working)
Get the name of your wireless interface
```bash
iw dev
```
To check link status, use following command
```bash
iw dev interface link
```
You can get statistic information, such as the amount of tx/rx bytes, signal strength etc., with following command
```bash
iw dev interface station dump
```
Some cards require that the kernel interface be activated before you can use iw or wireless_tools
```bash
ip link set interface up
```
To see what access points are available
```bash
    iw dev interface scan | less
```
Connect to an access point
* No encryption
    ```bash
    iw dev interface connect "your_essid"
    ```
* WEP
    ```bash
    iw dev interface connect "<your_essid>" key 0:<your_key>
    ```
Try to ping google.com
```bash
ping google.com
```
Use *elinks* to browse the internet in CLI (Command Line Interface), for instance https://wiki.archlinux.org/index.php/Installation_guide
```bash
elink https://github.com/JosephLucas/archlinux_installation
```
(or https://github.com/JosephLucas/archlinux_installation)

## Prepare installation
Update pacman database
```bash
pacman -Syy
```
set timezone (it seems needed for pacman)
```bash
timedatectl set-timezone Europe/Paris
```

### Edit partitions
Use parted to edit partitions
```bash
parted /dev/sdX
```
``` 
(parted) rm X
(parted) mkpart primary ntfs 0% 100GB
(parted) mkpart primary ext4 100GB 100%
```
Label partitions
```bash
mkfs.ntfs -f /dev/sda1 -L windows
fatlabel ...
```
(By experience, I advice you to avoid LVM, you will avoid losing a lot of time for not much help.
If you really want to, read following section.)

### Manage Logical volumes 
```bash
pvcreate ...
vgcreate ...
lvcreate ... -L 50GB -n lv_debian
lvcreate ... -l 100%FREE -n lv_arch_home
```

Instead of `/dev/sdXX`, a lvm partition looks like `/dev/mapper/vg_ssd-lv-root`

If you plan to resize some logival volumes, do not forget to:
* shrink the file system **before** shrinking the logical volume
* extend the logical volume **before** extending the file system)

If LVM partitions are used, the ESP is mounted at /boot; contrary to the standard mountpoint of the ESP.
(cf http://www.rodsbooks.com/refind/installing.html). Cause, rEFInd doesn't seem to read LVM partitions whereas Arch
installs bootloader and iniramfs into /boot with pacstrap and mkinitcpio.
Another solution would be to move the images and the refind_linux.conf from /boot/ (into LVM/ext4) to /boot/efi
(into the ESP) each time they are upgraded :

    do not launch ! (mv) /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img /boot/refind_linux.conf /boot/vmlinuz-linux /boot/refind_linux.conf /boot/efi

Just before creating an initial ramdisk environment (mkinitcpio), add 'lvm2" in the HOOKS of /etc/mkinitcpio.conf. 

    HOOKS="base udev ... block lvm2 filesystems"
The order seems important.

### Do not make a swap partition
Do not make a *swap*, use instead a *swap file*, it is more flexible. (see https://wiki.archlinux.org/index.php/swap#Swap_file)

### Mount partitions
With:
* `/dev/sdXX` the partition for root 
* `/dev/sdYY` the partition for home 
```bash
mount /dev/sdXX /mnt
mkdir /mnt/home
mount /dev/sdYY /mnt/home
```
Mount the EFI System Partition (ESP)
```bash
mkdir -p /mnt/boot/efi
mount /dev/sdb1 /mnt/boot/efi
```
### Rank pacman mirrors    
```bash
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
rankmirrors -n 20 /etc/pacman.d/mirrorlist.backup > /etc/mirrolist
```

## Install Arch
```bash
pacstrap /mnt base base-devel
pacstrap /mnt vim
``` 
Install Wifi; wpa_supplicant is for wpa/wep support
```bash
pacstrap /mnt iw wpa_supplicant
```
(You could also install dialog for a wifi-menu)

Install a desktop environment
```bash
pacstrap /mnt xfce4 xfce4-goodies xorg-server
```
Install Firefox (and elinks, just in case you cannot start the graphic server)
```bash
pacstrap /mnt firefox elinks
```
### Generate the table of file system and mount points
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```
### Chroot into the newly installed arch
```bash
arch-chroot /mnt
```
Give a name to the machine (for instance asus_ux32vd)
```bash
echo <name> /etc/hostname
```
Give a name for the net
```bash
echo '127.0.0.1 asus_ux32vd.localdomain asus_ux32vd'  >> /etc/hosts
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
```
### Set local language
```bash
vim /etc/locale.gen
```
Then uncomment the line `en_US-UTF-8 UTF-8`
```bash
locale-gen
echo LANG="en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8
echo KEYMAP=fr-latin1 > /etc/vconsole.conf
```
### Customize pacman
```bash
vim /etc/pacman.conf
```
* uncomment `Color`
* add line `ILoveCandy` for a funny animation when installing packages with pacman 
* uncomment `multilib` repo if you want to enable running and building 32-bit applications on 64-bit installations of Arch Linux. 

### Create an initial ramdisk environment 
```bash
mkinitcpio -p linux
```
### Install the boot loader rEFInd 
Here we use rEFInd.

By default, rEFInd scans all disks and locates all EFI bootloaders that can be launched with the UEFI.
An easy way to configure a linux bootloader is to add a `refind_linux.conf` next to it, e.g.
A more exhaustive configuration can be made through a manual "stanza" in `/boot/efi/EFI/refind/refind.conf`

Let's install rEFInd
```bash
pacman -S refind-efi
refind-install
```
`refind-install` automatically generates the `refind_linux.conf` next to the linux image.
It can be edited with
```
vim /boot/refind_linux.conf
```
You might need to remove the 2 first lines that may correspond to the Arch Linux Live USB.

Otherwise, edit the arch linux stanza in `/boot/efi/EFI/refind/refind.conf` to get
```
menuentry "Arch Linux" {
    icon     EFI/refind/icons/os_arch.png
    volume   arch_root
    loader   /boot/vmlinuz-linux
    initrd   /boot/initramfs-linux.img
    options  "ro root=UUID=57203de9-12fc-419c-a358-7b880da80e38"
    ostype   "Linux"
    submenuentry "Boot using fallback initrd" {
		initrd /boot/initramfs-linux-fallback.img
	}
}
```
where
* "EFI/refind/icons/os_arch.png" is the path from the root of the ESP disk to the icon file
* "arch_root" is the disk label. (this line corresponds to change the working directory)
* "/boot/vmlinuz-linux" is the path to the linux kernel (on the "arch_root" volume)
* "/boot/initramfs-linux.img" is the path to the linux initialisation RAM file system image
The UUID of the linux OS disk (UUID=57203de9-12fc-419c-a358-7b880da80e38) can be found with `lsblk -f`.

NB: The "fallback" image utilizes the same configuration file as the default image, except the autodetect hook is skipped
during creation, thus including a full range of modules. The autodetect hook detects required modules and tailors the
image for specific hardware, shrinking the initramfs.

#### tricks with rEFInd

On the rEFInd boot screen:
* press F10 to make screenshots. Images are saved at the main dir of refind "ESP/refind/".
* on a bootloader entrypoint press DEL to hide an entry. You cann restore it with the "configuration of hidden tags" icon afterwards.

### Set a password for the root
```bash
passwd
```
### Reboot
`Ctr + D`
```bash
unmount -R /mnt
reboot
```

## Post-Installation configuration

### Micro-code of Intel CPUs
Look for your processor model at 
https://downloadcenter.intel.com/fr/product/65707/Intel-Core-i5-3317U-Processor-3M-Cache-up-to-2-60-GHz-

If you need microcode,
```bash 
pacman -S intel-ucode
vim /boot/refind_linux.conf
```
and insert `initrd=/boot/intel-ucode.img` just before `initrd=/boot/initramfs-linux.img`, with spaces between options.

After a reboot, check that microcode is 'updated early'
```bash
dmesg | grep microcode
```
### Activate TRIM (for saving your an SSD lifetime)
Following https://wiki.archlinux.org/index.php/Solid_State_Drives#Maximizing_performance

Check if you have a ssd disk with a TRIM available 
```bash
lsblk -D
```
non-0 DISK-GRAN or DISK-MAX means that the device supports TRIM.

Enable fstrim.timer to be started on bootup
```bash
systemctl enable fstrim.timer
```
### Optimize SSD
From https://wiki.archlinux.fr/SSD#Option_de_montage_noatime

Add option **noatime** in /etc/fstab for partitions on the ssd. (It should already be the case by default)

### Desktop environment xfce4
Start the graphical window manager
```bash
startxfce4
```
### Install xfce4-goodies
```bash
pacman -S xfce4-goodies
```
Change icon `/usr/share/icons/hicolor/48x48/apps/xfce4-time-out-plugin.png` because it graphically looks like the clock icon.

Within a xfce4 graphical session switch to a consol tty

    ctr + alt + fX 
(with X in [1-6])

To come back to the xfce4 session 

    ctr + alt + f7 
(ctr + alt + f1 doesn't work for unknown reasons)

### Unmute sound 
```bash
pacman -S alsa-utils
alsamixer
```
unmute the master channel (MM) by selecting it and pressing 'm', then increase volume untill reaching a 0dB filtering.
```bash
pacman -S pulseaudio
```
You might need
```bash 
pacman -S xfce-pulseaudio-plugin
pacman -S pavucontrol
```
and might also need to restart.

If pulseaudio cannot start (e.g. by trying the command `pulseaudio`), and if it raises
```
E: [pulseaudio] core-util.c: Home directory not accessible: Permission denied
```
Then
```
sudo chown -R $USER:$USER $HOME
```
Start and enable the *user* daemon
```
systemctl --user restart pulseaudio.service
systemctl --user enable pulseaudio.service
```
(NB: pulseaudio should not be started as a sudo)

### Configure an automated connection to the internet
```bash
ip link show
```
Note the names of the interfaces (for instance 'lo' and 'wlp3s0').

Automatically connect to the wifi (https://wiki.archlinux.fr/Netctl#Connexion_automatique_.C3.A0_un_profil)
```bash
pacman -S wpa_actiond
systemctl enable netctl-auto@wlp3s0.service
```
Automatically switch wifi network connection
```bash
systemctl enable netctl-auto@<wifi-interface>.service
```
Get the ethernet interface with
```bash
ip link
```
Then, to enable auto-connection when the ethernet cable is plugged in/unplugged
(https://wiki.archlinux.org/index.php/netctl#Usage)
```bash
sudo pacman -S ifplugd
sudo systemctl start netctl-ifplugd@<ethernet-interface>.service
sudo systemctl enable netctl-ifplugd@<ethernet-interface>.service
```
(it might be useful to `rm /var/lib/dhcpcd/*.lease`)
### Create a non-root user
with default shell = ZSH
```bash
pacman -S zsh
useradd -m -g wheel -s /bin/zsh <user>
passwd <user>
 ```
 If needed, give sudo rights to `<user>`
```bash
visudo
```
### Make zsh the default shell
(NB: Overall ranking of zsh configs seems to be `grml-zsh-config` > `prezto` > `Oh-my-zsh.` The two former frameworks are bloated. 
From https://www.reddit.com/r/unixporn/comments/48wmfr/zsh_users_which_do_you_prefer_oh_my_zsh_or_prezto/)
Install the default config for arch (same as in the USB stick)
```bash
pacman -S grml-zsh-config
```
List available shells
```bash
chsh -l
```
Make zsh the default shell
```bash
chsh -s /bin/zsh
```
NB: Usually zsh is used in Emacs mode. If the vim mode was accidentally set, Emacs mode can be set back at any time with
```bash
bindkey -e
```
### Install a Windows Display Manager
```bash
lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
systemctl enable lightdm
```

Set a background for all users
```bash
sudo cp /home/jlucas/Images/xxx.png /home/
```
Give permission rights to the image for the background of LightDM
```bash
sudo chmod uog+rwx /home/xxx.png
```
Settings > LightDM + Greeter > background image

### Switch xfce4 and lightdm into azerty
```bash
localctl --no-convert set-x11-keymap fr
``` 
### Swap file
(see https://wiki.archlinux.org/index.php/Swap#Swap_file)
```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```
edit `/etc/fstab` to add an entry for the swap file:
echo '/swapfile	none	swap	defaults	0 0' | sudo tee -a /etc/fstab

Then
```bash 
pacman -S systemd-swap
```
set `swapfc_enabled=1` in the Swap File Universal section of `/etc/systemd/swap.conf`
```bash 
systemctl enable systemd-swap.service
```
#### Swappiness
Show current swappiness
```bash
cat /proc/sys/vm/swappiness
```
Edit `/etc/sysctl.d/99.sysctl.conf`
```bash
vm.swappiness=15
```
When 85% RAM is used (15% of free ram is remaining), the kernel is allowed to use the swapfile.

### Setting touchpad
In  Applications > Setting > Mouse and Touchpad, set tap click and scrolling.

(If necessary install xf86-input-synaptics with pacman and read https://wiki.archlinux.fr/Touchpad_Synaptics)

### Auto-mount USB devices
```bash
pacman -S udisks2 
pacman -S thunar-volman gvfs
```

In Thunar (default folder/files manager of xfce4)
    Edit -> Preferences
    Tab « Advanced » on the right
    Check « activate device manager »

If you want to be able to write on a mounted ntfs disk:
```bash
pacman -S ntfs-3g
```

### customize Thunar
Remove the buggy "set as default wallpaper" when right click on an image
```
sudo mv /usr/lib/thunarx-3/thunar-wallpaper-plugin.so{,.disabled}
```

#### Add custom actions, when right click on a file/folder
Add a custom action Edit->Configure custom actions...

Have a look at https://docs.xfce.org/xfce/thunar/custom-actions

(trick: to monitor/debug a xfce channel
```
xfconf-query -c xfce4-desktop -m
```)

### Removable drives and media
Applications > Settings > Appearance > Removable drives and media
Check 'Automatically mount' 

### Customize rEFInd
Download asus logo http://logo-logos.com/wp-content/uploads/2016/10/Asus_logo_black_and_white.png
Shrink Asus logo to 800px in width and 24bits depth for colors.
```bash
convert -colors 256 -depth 24 +dither -resize 800 ~/Desktop/logo_asus.png ~/Desktop/logo_asus_24b.png
```
Download snowy icons (https://sourceforge.net/projects/refind/files/themes/)
```bash
pacman zip unzip
```
Move the logo and the snowy folder in /boot/EFI/refind/themes (`mkdir /boot/efi/EFI/refind/themes`)
```bash
echo 'banner /EFI/refind/themes/logo_asus_24b.png' | sudo tee -a /boot/efi/EFI/refind/refind.conf
```

#### If you want to discard automated detection of efi boot loaders

At the end of `/boot/efi/EFI/refind/refind.conf` write

    # Personal config, using the partition label for the volume
    menuentry "Arch Linux" {
        volume   "arch_root"
        icon     /boot/efi/EFI/refind/icons/os_arch.png
        loader   /boot/vmlinuz-linux
        initrd   /boot/initramfs-linux.img
        options  "ro root=/dev/sdb2 add_efi_memmap loglevel=3"
        ostype   "Linux"
        submenuentry "Boot using fallback initramfs" {
            initrd initramfs-linux-fallback.img
        }
        submenuentry "Boot to terminal" {
            add_options "systemd.unit=multi-user.target"
        }
    }

Change 'scanfor manual' to hide other unconfigured bootloaders.
### Trizen for AUR packages
```bash
git clone https://aur.archlinux.org/trizen-git.git
cd trizen-git
makepkg -si
cd -
```
### Ethernet (usb ASIX Electronics Corp. AX88179 Gigabit Ethernet)
Intall driver from AUR and dependency (linux-headers for the kernel
module of the driver)
```bash
pacman -S linux-headers
trizen -s asix-ax88179-dkms
```
Configure netctl
```bash
cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/
netctl start ethernet-dhcp
netctl enable ethernet-dhcp
```
### Pycharm
IDE python : pychamr
```bash
pacman -S pycharm-community-edition
```
Set pycharm diff tool has the default diff tool (not recommanded, since pycharm is quite slow... use meld instead)
```bash
sudo echo 'export DIFFPROG="pycharm diff"' >> ~/.zshrc
sudo DIFFPROG='pycharm diff' pacdiff
```
### Install Meld for file/folder/vcs comparisons
```bash
sudo echo 'export DIFFPROG="meld"' >> ~/.zshrc
pacman -S meld
```
### Set a dark Arch linux theme for XFCE + some tweaks/tunings
Install a dark gtk theme
```bash
trizen -S gtk-theme-arc-git
```
Applications > Settings > Appearance > Arc-Dark
Applications > Settings > Window Manager > Arc-Dark

Install an extension for black background on firefox
```bash
``'Dark Background and Light Text'
```

Set wallpaper : http://cinderwick.ca/files/archlinux/wallpaper/archlinux-xfce-azul.jpg

Remove some icons (specially important for avoiding drag-n-drop in root)

Settings > Desktop > Icons > (uncheck 'FileSystem' and 'Removable Devices')

Install icon themes
```bash
trizen -S humanity-icon-theme
```
(`papirus-icon-theme` and `arc-icon-theme` are also good choices)

Settings > Appearance > Icons > Humanity

### Monitoring CPU,RAM,SWAP with conky
```bash
pacman -S conky pacman-contrib
```
(pacman-contrib gives the command checkupdates used to show the number of updates available)
```bash
mkdir -p ~/.config/conky
```
Default configuration
```bash
conky -C > ~/.config/conky/conky.conf
```

Download versioned configuration file
```bash
wget https://raw.githubusercontent.com/JosephLucas/configs/master/.config/conky/conky.conf
cp ~/.config/conky/conky.conf{,.bak}
mv conky.conf ~/.config/conky/conky.conf
```

Enable conky to auto-start
```bash
wget https://raw.githubusercontent.com/JosephLucas/configs/master/.config/autostart/conky.desktop
mkdir -p ~/.config/autostart
mv conky.desktop ~/.config/autostart
```

(inspiration: last post of angstrom https://forum.xfce.org/viewtopic.php?id=6847)
(documentation http://conky.sourceforge.net/config_settings.html)

### Plank dock (Macos like panel)
```bash
trizen -S plank-theme-arc
```
Configure Plank
1. Hold down Control and right click anywhere on the dock
2. Select "Preferences"

#### Fix annoying shadow bar next to Plank dock
Settings > Window Manager Tweaks > Compositor tab > untick the ‘Show shadows under dock windows’ checkbox

### xfce shortcuts
To open the *whisker menu* of the panel with the `windows` key, go to Settings -> Keyboard -> Application Shortcuts.
Add the command `xfce4-popup-whiskermenu` in the list.

### Configure xfce panel
Settings > Panel > Add the "whisker menu" item and remove "Applications menu".

Fix trouble editing the account top-left xfce whisker menu
 ```bash
trizen -S mugshot
 ```

###Low battery warning
First tried to set a systemd/timer for notify-send but (https://stackoverflow.com/a/49617812) advised not to do that.
Finally opted for 1) of (https://bbs.archlinux.org/viewtopic.php?id=189307)

Install a tool to monitor battery (https://unix.stackexchange.com/a/60936)
```bash
pacman -S acpi
```

Download and install daemon script
(https://wiki.archlinux.org/index.php/Systemd/Timers)
```bash
wget https://raw.githubusercontent.com/JosephLucas/archlinux_installation/master/low_battery_warning.sh
sudo install -o root -g root -m 755 low_battery_warning.sh /usr/local/bin
rm low_battery_warning.sh
```

### Albert (fast launcher from keywords)
```bash
trizen -S albert
```
### Instant messagery with Pidgin
```bash
pacman -S pidgin
pacman -S purple-facebook
pacaur -S telegram-purple
pacman -S purple-skypeweb
```
Note that pidgin may play a sound at startup. This can be deactivated Tools > Mute sounds

For minimized window at start: Tools > check Extended Preferences > configure plugin > Hide buddy list at startup

```bash
trizen -S pidgin-extprefs
```
Have a look at https://github.com/JD342/arc-thunderbird-integration

### Download interfaces
```bash
pacman -S wget rsync aria2 uget
```

### Mail client : neomutt
see https://www.neomutt.org/distro/arch
```bash
mkdir -p /tmp/makepkg && cd /tmp/makepkg
wget https://aur.archlinux.org/cgit/aur.git/snapshot/neomutt.tar.gz
tar xf neomutt.tar.gz
cd neomutt
makepkg -si
```
### Drivers
#### NVIDIA optimus graphic cards
(see https://wiki.archlinux.org/index.php/NVIDIA_Optimus)

Find out the model of your graphic card
```bash
lspci | grep -E "VGA|3D"
```

### Graphic cards (Optimus = (HD4000 + Geforce GT 620 M))
https://www.reddit.com/r/linux_gaming/comments/6ftq10/the_ultimate_guide_to_setting_up_nvidia_optimus/

1) install bumblebee

https://wiki.archlinux.org/index.php/Bumblebee#Installing_Bumblebee_with_Intel.2FNVIDIA
Ensure you have enabled "multilib" repository: be sure both lines are uncommented in `/etc/pacman.conf`

    [multilib]
    Include = /etc/pacman.d/mirrorlist

```bash
pacman -S bumblebee mesa nvidia lib32-virtualgl lib32-nvidia-utils
```
(Note xf86-video-intel does not seem necessary)

Add <user> to the group that is allowed to run bumblebee
```bash
gpasswd -a <user> bumblebee
systemctl enable bumblebeed.service
```
Tester (optirun a des meileurs performances que primusrun)
```bash
pacman -S virtualgl
glxspheres64
```
```bash
optirun glxspheres64
optirun glxspheres32
```
2) Install nvidia-xrun and the lightweight Desktop Environment
```bash
trizen -S nvidia-xrun
pacman -S openbox
```
In `~/.nvidia-xinitrc`, add a line that starts `openbox-session`
```bash
echo -e '# start the window manager\nopenbox-session' >> ~/.nvidia-xinitrc
```

Configure Openbox (https://wiki.archlinux.org/index.php/openbox#Configuration)
```bash
cp -R /etc/xdg/openbox ~/.config/
```
In `~/.config/openbox/autostart`, ensure that keyboard is properly set to AZERTY

    # personal config (jlucas)
    #
    # change  keyboard to fr-latin1 (azerty)
    (sleep 2s && setxkbmap fr-latin1 oss) &
```bash
echo '\n# personal config (jlucas)\n#\n# change  keyboard to fr-latin1 (azerty)\n(sleep 2s && setxkbmap fr-latin1 oss) &' >> ~/.config/openbox/autostart
```

Next lines describe how to Activate the Geforce gt 620 M in openbox.

Logout from the xfce4 DE
```bash
xfce4-session-logout
```
Switch to a tty; e.g. 
    
    Ctr+Alt+F2

Activate the Geforce 620M and start openbox DE with this graphical acceleration
```bash
nvidia-xrun
```
Load AZERTY keyboard layout
```bash
setxkbmap fr oss
```
If you want to use XFCE config tools within openbox (switch keyboard layout): 
```bash
xfce4-mcs-manager
```
In the light-weight DE openbox you can now launch the 3D application.

For instance open a terminal and 
```bash
glxspheres64
```
Performances should be impressive !

For stats about the video card
```bash
nvidia-settings -q screens -q gpus -q framelocks -q fans -q thermalsensors
```
(terse option, add : -t)

### Wine (allow executing some windows applications natively)
Here also, ensure you have enabled pacman "multilib" repository.

```bash
sudo pacman -S wine
```
(use default providers if you are asked for a choice)

For sound 
```bash
pacman -S lib32-libpulse
```

Configure wine
```bash
wine winecfg
```
Do install .NET and Gecko in graphical popups
```bash
wine control
```

### Install Battlenet client
```bash
pacman -S winetricks lib32-gnutls lib32-libldap
winetricks corefonts
```
### Fix the icon of wine in the menu
```bash
for f in ~/.local/share/icons/hicolor/*/apps/1CD8_rundll32.0.png; do cp $f $(dirname $f)/wine.png; done
```
with ~/.local/share/icons/hicolor/*/apps/1CD8_rundll32.0.png convenient icons of wine for different sizes (*)

To update the icon cache, log out and in.
### Fix blackscreen and error when starting Heroes Of The Storm
https://eu.battle.net/forums/en/heroes/topic/17612391410

Before starting the game (from battlenet client app)
Game settings > additional command line arguments > "-dx9"

### Htop
```bash
pacman -S htop
```

### SSH
Install ssh
```
sudo pacman -S openssh
```
Start a ssh server
```
sudo systemctl start sshd
```
Gnerate ssh key pairs
```
ssh-keygen
```
Copy public key to .ssh/authorized_keys of a desired ssh server
```
ssh-copy-id <remote-user>@<host>
```
Edit .ssh/config
```
Host raspberry
    HostName 192.168.10.1
    Port 22
    User pi
```
To avoid writing id_rsa passphrase for each connection
```
ssh-add
```
(NB: this presuposes that `ssh-agent` is already running)
### VLC
```bash
pacman -S vlc qt4 libcdio
```
### Mount an Android smartphone device via USB
Activate the MTP protocol on the smartphone, then
```bash
pacman -S jmtpfs
mkdir /mnt/smartphone
jmtpfs /mnt/smartphone
```
### Nextcloud (fork of Owncloud)
```bash
pacman -S nextcloud libgnome-keyring
```
libgnome-keyring is necessary to store the password

### Pdf viewer
```bash
trizen -S acroread
```

### Handle archive formats
```bash
pacman -S p7zip p7zip-plugins tar
```

### Fix screen tearing issues with the default window compositor of xfce4
XFCE default compositing window manager (https://wiki.archlinux.org/index.php/Xorg#Composite) and default nvidia configuration had me experience screen tearing.

A solution is to install *compton*, a 'compositing window manager

Deactivate default xfce composite manager (window manager tweak-> manager->Disable) and installing compton 
```bash
pacman -S compton
```
then follow 
https://ubuntuforums.org/showthread.php?t=2144468&p=12644745#post12644745
for configuration with xfce.

Other tried solution (Tried and crashed my graphic server):

https://wiki.archlinux.org/index.php/Intel_graphics#Tear-free_video

I created file : `/etc/X11/xorg.conf.d/20-intel.conf`
with :

	Section "Device"
	  Identifier  "Intel Graphics"
	  Driver      "intel"
	  Option "TearFree" "true"
	EndSection 

### xfce keyboard shortcuts

Setting Manager -> Keyboard -> Application Shortcuts and add the command "xfce4-screenshooter"

Do the same for the consol "xfce4-terminal"
### Manager of archives :
(same as ubuntu's)
```bash
pacman -S file-roller
```
### Redhift
Shift colors depending on the hour of the day (help your eyes hurt less if you are working in front of the screen at night)
`redshift`

[In order to allow access Redshift to use GeoClue2, add the following lines to /etc/geoclue/geoclue.conf](https://wiki.archlinux.org/index.php/redshift#Configuration):
```
[redshift]
allowed=true
system=false
users=
```

### Docker
```bash
pacman -S docker
sudo systemctl enable docker.service
```
Add the user to the group
```bash
sudo gpasswd -a jlucas docker
```

### Install proprietary software [Antidote](https://www.antidote.info/en)
With the installer version over ./Antidote_9.5.3_B_31_Linux.bash things should go smoothly.
Do remind to install firefox/thunderbird extensions.
Do not read what goes next if things went smoothly.

Otherwise have a look to the [reddit post](https://www.reddit.com/r/archlinux/comments/95z60b/antidote_freeze_anyone/e83aj0c/?context=8&depth=9)
that covers an in-depth fix of Antidote installer for Ach linux.
I also tried:
```
sudo pacman -S xhost
sudo bash Antidote_9.5.2_B_21_Linux.bash
```
After installation, grant access X server to everyone
```
xhost +
```
It was important to execute Antidote_9.5.2_B_21_Linux.bash as sudo to avoid the error:
```
/usr/bin/env: ‘./Antidote_9.5.2_B_21_Linux.bash’: No such file or directory
```

### Download mp3 from youtube videos
```bash
pacman -S youtube-dl ffmpeg
youtube-dl --extract-audio --audio-format mp3 <url>
```
For more, https://askubuntu.com/questions/178481/how-to-download-an-mp3-track-from-a-youtube-video

### Other packages
`xkill`

## Hints and unsuccessful tries

https://forum.owncloud.org/viewtopic.php?t=29048
Non automatic login of owncloud-client at startup

### Thunar right click action "set as wallpaper" on a picture isn't working
https://forum.xfce.org/viewtopic.php?id=12322

### Improvement of Plank
Remove the anchor icon
```bash
gconftool-2 --type Boolean --set /apps/docky-2/Docky/Items/DockyItem/ShowDockyItem False
```

### Bluetooth pairing of the headset, Bose Quiet Confort q35
NB: I didn't manage to enable bluetooth connection -> plug it with a jack wire

Unsuccessful try:

https://eklausmeier.wordpress.com/2016/10/26/bluetooth-headphones-in-arch-linux/
https://wiki.archlinux.org/index.php/Blueman

(Note the existence of https://github.com/Denton-L/based-connect
sudo pacaur -S based-connect-git)

sudo pacman -S bluez bluez-utils
sudo pacman -S pulseaudio-bluetooth
(sudo pacman -S blueman)

Load the generic bluetooth driver, if not already loaded (important!): 
    modprobe btusb

in /etc/bluetooth/main.conf :

    ControllerMode = bredr
    [Policy]
    AutoEnable=true


By default the bluetooth daemon will only give out bnep0 devices to users that are a member of the lp. So launch 

    sudo bluetoothctl

(without sudo, commands may not work)

    help
    show
    devices
    pair xx:yy:...
    trust xx:yy:...
    connect xx:yy:...
    paired-devices

(xx:yy:... is the MAC address)

https://erikdubois.be/installing-bose-quietcomfort-35-linux-mint-18/

in a newly created file /etc/bluetooth/audio.conf
Copy/paste these lines inside. Do not change anything. The order is important.

    [General]
    Disable=Socket
    Disable=Headset
    Enable=Media,Source,Sink,Gateway
    AutoConnect=true
    load-module module-switch-on-connect


## List of interesting packages
Manage your money (allow connection to your bank account with specific protocols)
`gnucash` 
Edit pdfs
`masterpdfeditor`
Analyse Disk usage
`baobab`

(from http://sametmax.com/mon-environnement-de-travail/)
Agregator of RS feeds (have a look at "Tiny RSS" too)
`liferea`
Snapshot with integrated util to edit (avoid openning gimp a posteriori)
`shutter`
Editing pdfs
`pdfmod`

It might be interesting to have a look at 

    aria2: a lightweight multi-protocol & multi-source command-line download utility
    uget: a download manager which can use aria2 as a back-end by enabling a built-in plugin
and 
    
    visual studio code
    bash debug: bashdb (also a plugin for visual studio code)
    shellcheck (also a pycharm plugin)
## TODO
Wayland (emulate Xserver with xWayland)
installation process for virtualbox
activates HOOKS requested for kvm
use Wayland or XWayland as soon as XFCE allows it

## Tips
Use TestDisk or parted in rescue mod to rescue erroneous partition tables

## Glossary
Arch linux Rollback Machine (ARM)
Arch Linux Archive (ALA) where previous versions of packages are archived

## Obsolete

### Manjaro ZSH configuration (switched to grml)
If you want to install the configuration of the ZSH of manjaro (see file *zshrc_manjaro* attached) 
```bash
#enable fish-like style features
sudo pacman -S zsh-syntax-highlighting
pacaur -S zsh-history-substring-search-git
pacaur -S zsh-autosuggestions
sudo pacman -S lsb-release
```
In the manjaro zhrc, change
```bash
echo $USER@$HOST  $(uname -srm) $(lsb_release -rs)
```
If grml-zsh-config is installed, add a first line in ~/.zshrc
```bash
add-zsh-hook -d precmd prompt_grml_precmd
```
whenever you want to customize your prompt. (see https://www.reddit.com/r/archlinux/comments/50sfdq/unable_to_change_zsh_command_prompt/)

### LXDM Display Manager (switched to lightdm)
```bash
pacman -S lxdm
```
I had trouble with the default keyboard in lxdm (the one of Xorg) and I needed to set the french azerty (with 'é'). For this I found some help on the internet.

https://wiki.gentoo.org/wiki/Keyboard_layout_switching
https://forum.voidlinux.eu/t/change-default-keyboard-for-lxdm-to-local-layout/972

An (ugly) solution is to create a /etc/X11/xorg.conf file with

    Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "fr"
    Option "XkbModel" "pc105"
    Option "XkbVariant" "azerty"
    Option "XkbRules" "evdev"
    Option "XkbOptions" "terminate:ctrl_alt_bksp"
    EndSection

####Install a dark Arch linux theme for LXDM
```bash
pacaur -S lxdm-themes
```
List all available themes 
```bash
ls /usr/share/lxdm/themes
vim /etc/lxdm/lxdm.conf
```
Change 

    theme=Archlinux

### Sublime (might be better to install "visual studio code" instead)
Sublime text editor (still with a non-sudo-user) 
```bash
trizen -S sublime-text
```

Solve icon of sublime, with plank, cannot be toggled to the dock (http://www.techbear.co/sublime-debian-plank/)

    sudo ln -s /opt/sublime_text/sublime_text /usr/bin/sublime

    sublime /usr/share/applications/sublime-text.desktop

    [Desktop Entry]
    Type=Application
    Name=Sublime Text Perso
    Comment=Sophisticated text editor for code, html and prose
    Exec=sublime %F
    Icon=sublime-text
    Categories=Utility;TextEditor;
    Terminal=false
    MimeType=text/plain;
    StartupNotify=true
    Actions=Window;Document;

    [Desktop Action Window]
    Name=New Window
    Exec=sublime -n
    OnlyShowIn=XFCE;
    Icon=sublime-text

    [Desktop Action Document]
    Name=New File
    Exec=sublime --command new_file
    OnlyShowIn=XFCE;
    Icon=sublime-text

