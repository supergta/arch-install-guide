#!/bin/bash

# Arch Linux Installation Script

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# --- Pre-Installation ---

# Set keyboard layout
loadkeys sv-latin1

# Verify UEFI boot mode
ls /sys/firmware/efi/efivars

# Connect to the Internet (manual intervention required for Wi-Fi)
echo "Please connect to the internet. For Wi-Fi, use iwctl."
read -p "Press Enter to continue after connecting..."

# Update system clock
timedatectl set-ntp true

# --- Disk Partitioning ---

# List available disks
lsblk
echo "Enter the disk to partition (e.g., /dev/sda):"
read DISK

# Partition the disk
gdisk $DISK <<EOF
o
Y
n
1

+512M
ef00
n
2


8300
w
Y
EOF

# --- Formatting and Mounting ---

# Format the partitions
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# Mount the filesystems
mount ${DISK}2 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

# --- Base System Installation ---

pacstrap /mnt base linux-zen linux-zen-headers nvidia-dkms grub efibootmgr networkmanager hyprland hyprlock ly hyprpaper wofi dunst wl-clipboard grim slurp cliphist polkit-kde-agent kitty thunar nano pipewire pipewire-pulse wireplumber pavucontrol steam lutris wine gamemode git nvtop ufw lxappearance ttf-jetbrains-mono-nerd-font

# --- System Configuration ---

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt <<EOF

# Set Timezone
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Localization
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "arch-hyprland" > /etc/hostname

# Set Root Password
echo "Set root password:"
passwd

# Configure mkinitcpio for NVIDIA
sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Install and Configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Create a User Account
echo "Enter your desired username:"
read USERNAME
useradd -m -G wheel $USERNAME
echo "Set password for $USERNAME:"
passwd $USERNAME

# Grant Sudo Privileges
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers

# Create Default Hyprland Config
mkdir -p /home/$USERNAME/.config/hypr
cp /usr/share/hyprland/hyprland.conf /home/$USERNAME/.config/hypr/hyprland.conf
echo 'exec-once = /usr/lib/polkit-kde-authentication-agent-1' >> /home/$USERNAME/.config/hypr/hyprland.conf
chown -R $USERNAME:$USERNAME /home/$USERNAME

EOF

# --- Post-Reboot Configuration ---

echo "Installation complete. Please reboot."
