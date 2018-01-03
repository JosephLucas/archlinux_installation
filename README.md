main inspirations
https://wiki.archlinux.org/index.php/installation_guide
https://wiki.archlinux.org/index.php/General_recommendations
https://wiki.archlinux.fr/installation
https://wiki.archlinux.org/index.php/ASUS_Zenbook_Prime_UX31A

# Installation of Arch Linux

##Download the last iso of Arch Linux
Use a miiror on https://www.archlinux.org/download/
I used https://arch.yourlabs.org/iso/2018.01.01/ because i'm in France.

## Create a USB arch linux live
Format your usb stick in fat32 (this will destroy your data)
    
    mkfs.vfat -n <name_for_your_pendrive> -I /dev/sdc

With sdX the USB stick device

    dd bs=4M if=arch.iso of=/dev/sdX
bs=4M **is** important to make the USB stick bootable 

## Boot from the USB stick in EFI mod
After booting, switch consol with

    Alt + lateral_arrow
Enter *root* as login.

    loadkeys fr-latin1
Verify that computer has booted in efi,

    efivar -l
should be non-null.

Offline documentation for the installation

    elinks /usr/share/doc/arch-wiki/html/index.html
or

    less ./install.txt

##Internet
###4G
Plug a 4G phone with USB tethering

    dhcpcd
###Wifi

    wifi-menu
Give a (name) to the config and enter a password if needed. This writte a file in /etc/netctl/(name). 
Load this file

    netctl start (name)
Try the connection

    ping google.com
Use elinks to browse the internet in CLI (Command Line Interface)

##Online documentation for the installation
elinks https://github.com/JosephLucas/archlinux_installation

## Prepare installation
Update pacman database

    pacman -Syy
set the timezone (it seems needed for pacman)

    timedatectl set-timezone Europe/Paris

###Backup former partitions
Tools

    lsblk 
    lsblk -f
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,PARTLABEL
    lskid

*ntfsresize* can resize windows partition (shrink or extend) without any previous defragmentation. ntfsclone copy ntfs partitions faster, good for backups !

    ntfsresize --info
This command tells you how much space is *really* used, that gives an advice to further resize the partition.
If 'disk as been scheduledfor *chkdsk*, you may need to relaunch windows that will launch the *chkdsk* tool to repare some errors in the *ntfs* partition.

    ntfsresize -s -o /mnt/depot_jo/Backup/windows.sepcial.img /dev/sdX

    ntfsresize --no-action --size 100G /dev/sdaX
    ntfsresize -v --size 100G /dev/sdaX
###Edit partitions
Use parted to edit partitions

    parted /dev/sdX 
    (parted) rm X
    (parted) mkpart primary ntfs 0% 100GB
    (parted) mkpart primary ext4 100GB 100%
Label partitions

    mkfs.ntfs -f /dev/sda1 -L windows
    fatlabel ...

(By experience, I advice you to avoid LVM, you will avoid losing a lot of time for not much help)
Logical volumes (see manuals)

    pvcreate ...
    vgcreate ...
    lvcreate ... -L 50GB -n lv_debian
    lvcreate ... -l 100%FREE -n lv_arch_home

    If you plan to resize some logival volumes, do not forget to :
    * shink the file system **before** shrinking the logical volume
    * extend the logical volume **before** extending the file system)

Do not make a *swap*, use instead a *swap file*, it is more flexible. (https://wiki.archlinux.org/index.php/swap#Swap_file)
	
    dd if=/dev/zero of=/swapfile bs=1M count=512
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
Finally, edit fstab to add an entry for the swap file:

    /swapfile none swap defaults 0 0

### Mount partitions

With:
* /dev/sdXX the partition for root (if lvm, /dev/mapper/vg_ssd-lv-root),
* /dev/sdYY the partition for home (if lvm, /dev/mapper/vg_hdd-lv-arch_home),

    mount /dev/mapper/vg_ssd-lv-root /mnt
    mkdir /mnt/home
    mount /dev/mapper/vg_hdd-lv-arch_home /mnt/home

Mount the EFI System Partition (ESP)

    mkdir -p /mnt/boot/efi
    mount /dev/sdb1 /mnt/boot/efi

Contrary to the standard mountpoint of the ESP (cf http://www.rodsbooks.com/refind/installing.html) we mount the ESP at /boot. Because rEFInd doesn't seem to read LVM partitions and Arch install bootimages into /boot with pacstrap and mkinitcpio.

Another solution would be to move the images and the refind_linux.conf from /boot/ (into LVM/ext4) to /boot/efi (into the ESP) each time they are upgraded :

    do not launch ! (mv) /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img /boot/refind_linux.conf /boot/vmlinuz-linux /boot/refind_linux.conf /boot/efi


## Update the mirror list    

    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    rankmirrors -n 20 /etc/pacman.d/mirrorlist.backup > /etc/mirrolist

## Install Arch

    pacstrap /mnt base base-devel
    pacstrap /mnt vim 
Wifi

    pacstrap /mnt iw wpa_supplicant dialog
(dialog is for wifi-menu and wpa_supplicant for wpa wifi)

Desktop environment

    pacstrap /mnt xfce4 xfce4-goodies xorg-server
Firefox

    pacstrap /mnt firefox elinks

## Configure Arch
### Generate the table of file system and mount points

    genfstab -U /mnt >> /mnt/etc/fstab

### Chroot into the newly installed arch

    arch-chroot /mnt
Give a name to the machine

    echo asus_ux32vd > /etc/hostname
Give a name for the net

    echo '127.0.0.1 asus_ux32vd.localdomain asus_ux32vd'  >> /etc/hosts
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

### Set local language

    vim /etc/locale.gen
Then uncomment the line "en_US-UTF-8 UTF-8"

    locale-gen
    echo LANG="en_US.UTF-8" > /etc/locale.conf
    export LANG=en_US.UTF-8
    echo KEYMAP=fr-latin1 > /etc/vconsole.conf

### Set apropriate HOOKS if you use LVM
If you use LVM, add 'lvm2" in the HOOKS of /etc/mkinitcpio.conf. 

    HOOKS="base udev ... block lvm2 filesystems"
The order seems important.

### Customize pacman

    vim /etc/pacman.conf
* uncomment *Color*
* add line *ILoveCandy*
* uncomment *multilib* repo

### Init ramdisk environment at boot

    mkinitcpio -p linux

### install a boot loader 
Here we use rEFInd.

    pacman -S refind-efi
    refind-install
    vim /boot/refind_linux.conf
remove the 2 first lines that correspond to the USB Live Arch.

### Set a password for the root

    passwd

### Reboot

    Ctr + D
    unmount -R /mnt
    shutdown 0

## After

### Micro-code of Intel CPUs
Look for your model here, if you need that.
https://downloadcenter.intel.com/fr/product/65707/Intel-Core-i5-3317U-Processor-3M-Cache-up-to-2-60-GHz-

    pacman -S intel-ucode
    vim /boot/refind_linux.conf
add 

    'initrd=/boot/intel-ucode.img initrd=/boot/initramfs-linux.img'

### TRIM (for saving your ssd lifetime)
https://wiki.archlinux.org/index.php/Solid_Statea_Drives#Maximizing_performance

    lsblk -D

non-0 DISK-GRAN or DISK-MAX means that the device support TRIM.

Enable fstrim.timer to be started on bootup

    systemctl enable fstrim.timer

### optimize SSD
https://wiki.archlinux.fr/SSD#Option_de_montage_noatime

Add option **noatime** in /etc/fstab for partitions on the ssd. ()

### XFCE
Start the graphical window manager

    startxfce4

###Unmute sound 

    pacman -S alsa-utils
    alsamixer

unmute the master channel (MM) by selecting it and pressing 'm', then increase volume untill reaching a 0dB filtering.

    pacman -S pulseaudio
You might need 

    pacman -S xfce-pulseaudio-plugin
    pacman -S pavucontrol
    
and might also need to restart.

### configure internet
(remplacant de ifconfig)

    ip link show
Note the names of the interfaces : here 'lo' and 'wlp3s0'.

Automatically connect to the wifi 
https://wiki.archlinux.fr/Netctl#Connexion_automatique_.C3.A0_un_profil

    pacman -S wpa_actiond
    systemctl enable netctl-auto@wlp3s0.service

Connection automatic en filaire

    systemctl enable netctl-auto@lo.service

###User
    pacman zsh
    useradd -m -g wheel -s /bin/zsh <user>
    passwd <user>
 
###Make zsh the default shell

    pacman -S zsh
Install the default config for arch (same as in the USB stick)

    pacman -S grml-zsh-config
    chsh -l
    chsh -s /bin/zsh

###Config Zsh
Overall grml-zsh-config > prezto > Oh-my-zsh. The two former frameworks are bloated. (https://www.reddit.com/r/unixporn/comments/48wmfr/zsh_users_which_do_you_prefer_oh_my_zsh_or_prezto/)

% If ever another configuration is intended
[comment]: <> (If you want to install the configuration of the ZSH of manjaro (see file *zshrc_manjaro* attached) )
[comment]: <> ()
[comment]: <> (    #enable fish-like style features)
[comment]: <> (    sudo pacman -S zsh-syntax-highlighting)
[comment]: <> (    pacaur -S zsh-history-substring-search-git)
[comment]: <> (    pacaur -S zsh-autosuggestions)
[comment]: <> (    sudo pacman -S lsb-release)
[comment]: <> ()
[comment]: <> (In the manjaro zhrc, change)
[comment]: <> ()
[comment]: <> (    echo $USER@$HOST  $(uname -srm) $(lsb_release -rcs[)
[comment]: <> ()
[comment]: <> ()
[comment]: <> ()
[comment]: <> (    echo $USER@$HOST  $(uname -srm) $(lsb_release -rs))
[comment]: <> ()
[comment]: <> (If grml-zsh-config is installed, add a first line in ~/.zshrc)
[comment]: <> ()
[comment]: <> (    add-zsh-hook -d precmd prompt_grml_precmd)
[comment]: <> ()
[comment]: <> (whenever you want to customize your prompt. (see https://www.reddit.com/r/archlinux/comments/50sfdq/unable_to_change_zsh_command_prompt/))



###Dipsplay manager (TODO: switch to lightdm)

    pacman -S lxdm

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

###Swap file
https://wiki.archlinux.org/index.php/Swap#Swap_file

    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

edit /etc/fstab and add

    /swapfile	none	swap	defaults	0 0

    pacman -S systemd-swap
    set 'swapfu_enabled=1' in the Swap File Universal section of /etc/systemd/swap.conf
    systemctl enable systemd-swap.service

####Swappiness
Current

    cat /proc/sys/vm/swappiness
Edit /etc/sysctl.d/99.sysctl.conf
vm.swappiness=15

From 85% of used RAM (15% of free ram), the kernel is allowed to use the swapfile.

###Customize rEFInd
Download asus logo http://logo-logos.com/wp-content/uploads/2016/10/Asus_logo_black_and_white.png
Edit the asus logo with gimp (pacman -S gimp imagemagick) to shrink it to 800 in width and 24 color bit depth.

    convert -colors 256 -depth 24 +dither ~/Desktop/logo_asus.png ~/Desktop/logo_asus_24b.png

download snowy icons https://sourceforge.net/projects/refind/files/themes/
pacman zip unzip

mkdir /boot/EFI/refind/themes
put the logo and the snowy folder in /boot/EFI/refind/themes

at the end of /boot/EFI/refind/refind.conf write

    # Personal config
    banner /EFI/refind/themes/logo_asus_24b.png
    menuentry "Arch Linux" {
        icon     /EFI/refind/themes/snowy/os_arch.png
        volume   /EFI
        loader   vmlinuz-linux
        initrd   initramfs-linux.img
        options  "ro root=/dev/mapper/vg_ssd-lv_root add_efi_memmap loglevel=3"
        submenuentry "Boot using fallback initramfs" {
            initrd initramfs-linux-fallback.img
        }
        submenuentry "Boot to terminal" {
            add_options "systemd.unit=multi-user.target"
        }
    }

Change 'scanfor manual' to hide other unconfigured bootloaders.

###Install pacaur (TODO: pacaur is dead, switch to trizen https://www.youtube.com/watch?v=Hx-8GFBtV6I)

Switch to a user without sudo power (as soon as you install AUR packages)

    cd /tmp
    git clone --depth=1 https://aur.archlinux.org/cower.git
    cd cower
    gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53
    makpkg -sri
    cd ..
    git clone --depth=1 https://aur.archlinux.org/pacaur.git
    cd pacaur
    makepkg -sri

###AUR install 
Sublime text editor (still with a non-sudo-user)
    
    pacaur -S sublime-text

IDE python : pychamr
    
    pacaur -S pycharm-community-edition

Set pycharm diff tool has the default diff tool (not recommanded, since pycharm is quite slow... use meld instead)

    #sudo echo 'export DIFFPROG="pycharm diff"' >> ~/.zshrc

    sudo DIFFPROG='pycharm diff' pacdif

####Install Meld for file/folder/vcs comparisons

    sudo echo 'export DIFFPROG="meld"' >> ~/.zshrc
    pacman -S meld

####Install a dark Arch linux theme for LXDM

    pacaur -S lxdm-themes

list all available themes 

    ls /usr/share/lxdm/themes
    vim /etc/lxdm/lxdm.conf

change 

    theme=Archlinux

####Set a dark Arch linux theme for XFCE + some tweaks/tunings

Install a dark gtk theme

    pacaur -S gtk-theme-arc-git

Applications > Settings > Appearance > Arc-Dark
Applications > Settings > Window Manager > Arc-Dark

Install an extension for black background on firefox

    'Dark Background and Light Text'

Set wallpaper : http://cinderwick.ca/files/archlinux/wallpaper/archlinux-xfce-azul.jpg

Remove some icons (specially important for avoiding drag-n-drop in root)

Settings > Desktop > Icons > (uncheck 'FileSystem' and 'Removable Devices') 

Install icons

    pacman -S arc-icon-theme 

Settings > Appearance > Icons > Arc

###Monitoring CPU,RAM,SWAP

pacman -S conky

mkdir -p ~/.config/conky
conky -C > ~/.config/conky/conky.conf

add in the config file

    background = true,

Add a ~/.config/autostart/conky.desktop:

    [Desktop Entry]
    Encoding=UTF-8
    Version=0.9.4
    Type=Application
    Name=conky
    Comment=
    Exec=conky -d -p 10
    StartupNotify=false
    Terminal=false
    Hidden=false
    OnlyShowIn=XFCE;

Add transparency

    last post of angstrom (https://forum.xfce.org/viewtopic.php?id=6847)

    alignment = 'bottom_right',

    double_buffer = true,
    format_human_readable = true,

    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'override',
    own_window_argb_visual = false,
    own_window_argb_value = 0,
    own_window_transparent = true,

(documentation http://conky.sourceforge.net/config_settings.html)

###Plank dock (Macos like panel)

    pacaur -S pacaur -S plank-theme-arc

remove the anchor icon

    gconftool-2 --type Boolean --set /apps/docky-2/Docky/Items/DockyItem/ShowDockyItem False 

solve icon of sublime the cannot be toggled to the dock (http://www.techbear.co/sublime-debian-plank/)

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
    
    
###Albert (fast launcher from keywords)

    pacaur -S albert
 
###Install xfce4-goodies !!!

    pacman -S xfce4-goodies

change icon /usr/share/icons/hicolor/48x48/apps/xfce4-time-out-plugin.png (because it interfers with clock)

###if trouble editing the account top-left xfce window-like start-app 

    pacaur -S mugshot

###Instant messagery

    pacman -S pidgin

Note that pidgin may play a sound at startup. This can be deactivated Tools > Mute sounds

    pacman -S purple-facebook
    pacaur -S telegram-purple
    pacman -S purple-skypeweb

For minimized window at start: Tools > check Extended Preferences > configure plugin > Hide buddy list at startup

    pacaur -S pidgin-extprefs

and

https://github.com/JD342/arc-thunderbird-integration

###Removable drives and media

    Applications > Settings > Appearance > Removable drives and media

    Automatically mount 

###Setting touchpad

Applications > Setting > Mouse and Touchpad
(set tap click and scrolling)

if necessary install xf86-input-synaptics with pacman and read https://wiki.archlinux.fr/Touchpad_Synaptics


###Mail client : neomutt (need wget : pacman -S wget)

see https://www.neomutt.org/distro/arch

    mkdir -p /tmp/makepkg && cd /tmp/makepkg
    wget https://aur.archlinux.org/cgit/aur.git/snapshot/neomutt.tar.gz
    tar xf neomutt.tar.gz
    cd neomutt
    makepkg -si

###Drivers
#### graphic cards
(see https://wiki.archlinux.org/index.php/NVIDIA_Optimus)
lspci | grep -E "VGA|3D"

### Graphic cards (Optimus = (HD4000 + Geforce GT 620 M))

https://www.reddit.com/r/linux_gaming/comments/6ftq10/the_ultimate_guide_to_setting_up_nvidia_optimus/

1) install bumblebee

https://wiki.archlinux.org/index.php/Bumblebee#Installing_Bumblebee_with_Intel.2FNVIDIA
    
    pacman -S bumblebee mesa nvidia lib32-virtualgl lib32-nvidia-utils

(Note xf86-video-intel does not seem necessary)

Add <user> to the group that is allowed to run bumblebee

    gpasswd -a <user> bumblebee
    systemctl enable bumblebeed.service

Tester (optirun a des meileurs performances que primusrun)

    pacman -S virtualgl
    glxspheres64
        
    optirun glxspheres64
    optirun glxspheres32

2) Installer nvidia-xrun
    
    pacaur -S nvidia-xrun
    pacman -S openbox
    sudo pacman -S openbox

In ~/.nvidia-xinitrc

    # start the window manager
    openbox-session

Configure Openbox (https://wiki.archlinux.org/index.php/openbox#Configuration)

    cp -R /etc/xdg/openbox ~/.config/

In ~/.config/openbox/autostart

    # personal config (jlucas)
    #
    # change  keyboard to fr-latin1 (azerty)
    (sleep 2s && setxkbmap fr-latin1 oss) &
    
Switch the DE (or )

    xfce4-session-logout

Switch to a tty; e.g. 
    Ctr+Alt+F2

Activate the geforce gt 620 M in openbox

    nvidia-xrun

If you want to use XFCE config tools in openbox : 

    xfce4-mcs-manager

In the light-weight DE openbox, launch the application
For instance open a terminal and 

    glxspheres64

Performances should be impressive !

For stats about the video card

    nvidia-settings -q screens -q gpus -q framelocks -q fans -q thermalsensors

(terse option, add : -t)

###Wine
wine-staging est la branche dev de wine, mais avec de sacrées améliorations !

    sudo pacman -S wine-staging 

Pour le son 

    sudo pacman -Qs lib32-libpulse
    
Note : It would also be intersting to look also at the package 'wine-staging-nine' for improvements of DirectX9 games with gallium patches.

Configure wine
    
    wine winecfg 
    (or winecfg maybe...)
    wine control

For Battlenet : https://wiki.archlinux.org/index.php/Blizzard_App

Install

    pacman -S winetricks lib32-gnutls lib32-libldap
    winetricks corefonts

###Auto-mount USB devices

    pacman -S udisks2 
    pacman -S thunar-volman gvfs

Ou peut-être plus simple (pas testé)
Dans Thunar (gestionnaire de fichiers) que ça se passe.
    Éditer -> Préférences
    Onglets « Avancée » tout à droite
    Cocher « activer le gestionnaire de volume »

###Htop

	pacman -S htop

###VLC

    pacman -S vlc

    I was necessary for me to install qt4

    pacman -S qt4

###owncloud

pacman -S owncloud-client libgnome-keyring
libgnome-keyring is to store the password

I prefer 

    pacaur -S nextcloud-client


###Pdf viewer

    pacaur -S acroread

## install compton, a 'compositing window manager'
(SKIP this first suggetion!)
XFCE default compositing window manager (https://wiki.archlinux.org/index.php/Xorg#Composite) and default nvidia configuration had me experience screen tearing

I solved it with
https://wiki.archlinux.org/index.php/Intel_graphics#Tear-free_video

I created file : /etc/X11/xorg.conf.d/20-intel.conf
with :

	Section "Device"
	  Identifier  "Intel Graphics"
	  Driver      "intel"
	  Option "TearFree" "true"
	EndSection

(Another solution would be to deactivate default xfce composite manager (window manager tweak-> manager->Disable) and installing compton 
    pacman -S compton
then follow 
https://ubuntuforums.org/showthread.php?t=2144468&p=12644745#post12644745
for configuration with xfce)

### pair bose quiet confort q35
https://eklausmeier.wordpress.com/2016/10/26/bluetooth-headphones-in-arch-linux/
https://wiki.archlinux.org/index.php/Blueman

(Note existence of https://github.com/Denton-L/based-connect
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

##xfce screenshooter shortcut keys

Setting Manager -> Keyboard -> Application Shortcuts and add the command "/usr/bin/xfce4-screenshooter"


## manager of archives : 
(same as ubuntu's)
pacman -S file-roller

## TODO

swap file
Wayland (emulate Xserver with xWayland)
install graphic cardds : https://www.reddit.com/r/linux_gaming/comments/6ftq10/the_ultimate_guide_to_setting_up_nvidia_optimus/
régler le problème avec wifi-menu
activer les HOOKS kvm et docker
compton : tear-free syncronization on XFCE
use Wayland or XWayland as soon as XFCE allows it

## installer :
gnucash
masterpdfeditor
pycharm
baobab redshift

# Index
* Arch linux Rollback Machine (ARM)
* Arch Linux Archive (ALA) where previous versions of packages are archived
* 
#Tricks
Use TestDisk or parted in rescue mod to rescue erroneous partion tables



INPROGRESS


TIPS:

for a xfce4 X session : ctr + alt + fX (with X in [1-6]) switch to a console tty.
To come back to the xfce4 session : ctr + alt + f7 ! (ctr + alt + f1 won't work)
openbox load AZERTY : setxkbmap fr oss

look at :
i3 rofi w3m firefox ranger vim mutt mpd newsbeuter pass





##Some cool stuffs
visual studio code
bash debug: bashdb (also a plugin for visual studio code)
shellcheck (also a plugin pycharm)