# Arch Linux Installation & Configuration Guide

This guide walks you through the entire process, from the live environment to a fully configured desktop. Execute the commands in order.

---

### 1. Pre-Installation (Live ISO Environment)

First, boot from the Arch Linux ISO. You will be dropped into a Zsh shell as the root user.

**Set keyboard layout:**
(Optional, defaults to US)
```bash
loadkeys sv-latin1
```

**Verify UEFI boot mode:**
This command should show a directory listing without errors.
```bash
ls /sys/firmware/efi/efivars
```

**Connect to the Internet:**
For Wi-Fi, use `iwctl`. For Ethernet, it should connect automatically.
```bash
# For Wi-Fi:
iwctl
# [iwctl] device list
# [iwctl] station <device> scan
# [iwctl] station <device> get-networks
# [iwctl] station <device> connect <SSID>
# [iwctl] exit
# Verify connection
ping archlinux.org
```

**Update system clock:**
```bash
timedatectl set-ntp true
```

---

### 2. Disk Partitioning

We will create an EFI System Partition and a root partition. Replace `/dev/sdX` with your target drive (e.g., `/dev/nvme0n1` or `/dev/sda`).

**Identify your disk:**
```bash
lsblk
```

**Partition the disk using `gdisk`:**
```bash
gdisk /dev/sdX
```
At the `gdisk` prompt, enter the following commands:
1.  `o` (Create a new empty GUID partition table) -> `Y` (Confirm)
2.  `n` (New partition) -> `1` (Partition number) -> `Enter` (First sector) -> `+512M` (Last sector) -> `ef00` (Hex code for EFI System)
3.  `n` (New partition) -> `2` (Partition number) -> `Enter` (First sector) -> `Enter` (Last sector, use remaining space) -> `Enter` (Hex code, default 8300 for Linux)
4.  `w` (Write changes to disk) -> `Y` (Confirm)

---

### 3. Formatting and Mounting

**Format the partitions:**
*   `/dev/sdX1` is the EFI partition.
*   `/dev/sdX2` is the root partition.
```bash
mkfs.fat -F32 /dev/sdX1
mkfs.ext4 /dev/sdX2
```

**Mount the filesystems:**
```bash
mount /dev/sdX2 /mnt
mkdir /mnt/boot
mount /dev/sdX1 /mnt/boot
```

---

### 4. Base System Installation

**Install core packages using `pacstrap`:**
This step will download and install the base system, kernel, and all specified desktop packages.
```bash
pacstrap /mnt base linux-zen linux-zen-headers nvidia-dkms grub efibootmgr networkmanager hyprland hyprlock ly hyprpaper wofi dunst wl-clipboard grim slurp cliphist polkit-kde-agent kitty thunar nano pipewire pipewire-pulse wireplumber pavucontrol steam lutris wine gamemode git nvtop ufw lxappearance ttf-jetbrains-mono-nerd-font
```

---

### 5. System Configuration (in `arch-chroot`)

**Generate fstab:**
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

**Enter the new system as root:**
```bash
arch-chroot /mnt
```

**Set Timezone:**
```bash
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc
```
*(Replace `Region/City` with your timezone, e.g., `Europe/Stockholm`)*

**Localization:**
Uncomment `en_US.UTF-8 UTF-8` (and any other needed locales) in `/etc/locale.gen`, then generate them.
```bash
nano /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

**Hostname:**
```bash
echo "arch-hyprland" > /etc/hostname
```

**Set Root Password:**
```bash
passwd
```

**Configure `mkinitcpio` for NVIDIA:**
Add NVIDIA modules to the initramfs to ensure they load early.
```bash
# Edit the file with nano
nano /etc/mkinitcpio.conf

# Find the MODULES=() line and change it to:
# MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

# Save the file and regenerate the initramfs
mkinitcpio -P
```

**Install and Configure GRUB:**
```bash
# Install GRUB for UEFI systems
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH

# Add the required kernel parameter for NVIDIA
nano /etc/default/grub

# Find the GRUB_CMDLINE_LINUX_DEFAULT="..." line and add nvidia_drm.modeset=1
# It should look like this:
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"

# Generate the final GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg
```

**Create a User Account:**
Replace `your_username` with your desired username.
```bash
useradd -m -G wheel your_username
passwd your_username
```

**Grant Sudo Privileges:**
Use `visudo` to safely edit the sudoers file.
```bash
EDITOR=nano visudo
```
Uncomment the following line to allow users in the `wheel` group to use `sudo`:
`%wheel ALL=(ALL:ALL) ALL`

**Create Default Hyprland Config with Polkit Agent:**
These commands must be run as root from within the `arch-chroot` environment.
```bash
# Create config directory for the new user
mkdir -p /home/your_username/.config/hypr

# Copy the default config to the user's directory
cp /usr/share/hyprland/hyprland.conf /home/your_username/.config/hypr/hyprland.conf

# Add the Polkit KDE Agent to the Hyprland config for autostart
echo 'exec-once = /usr/lib/polkit-kde-authentication-agent-1' >> /home/your_username/.config/hypr/hyprland.conf

# Set correct ownership for the user's home directory
chown -R your_username:your_username /home/your_username
```

**Exit and Reboot:**
```bash
exit
umount -R /mnt
reboot
```

---

### 6. Post-Reboot Configuration

After rebooting, you will be greeted by the Ly display manager. Log in with the user account you created. Open a terminal (Super + Enter for Kitty).

**Enable Core Services:**
```bash
sudo systemctl enable ly.service
sudo systemctl enable NetworkManager.service
sudo systemctl enable ufw.service
sudo ufw enable
```

**Install `paru` (AUR Helper):**
`paru` is needed to install packages from the Arch User Repository (AUR).
```bash
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -rf paru
```

**Install AUR Packages:**
```bash
paru -S thorium-browser-bin sublime-text-4 cyberpunk-neon-gtk-theme-revamped-git
```

**Set up Dotfiles Git Repository:**
This creates a bare repository to track your configuration files (`dotfiles`).
```bash
git init --bare $HOME/.dotfiles
alias dots='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
echo "alias dots='/usr/bin/git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME'" >> $HOME/.bashrc
source $HOME/.bashrc
```
You can now use the `dots` alias to manage your dotfiles (e.g., `dots status`, `dots add .config/hypr/hyprland.conf`, `dots commit -m "Initial Hyprland config"`).

**Final Steps:**
Your system is now fully installed and configured. You may want to use `lxappearance` to set the GTK theme to `cyberpunk-neon-gtk-theme-revamped-git` and reboot one last time for all changes to take effect.
