apt update
netplan generate
# change your locales, time zone, etc
echo -e 'de_DE.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\nlt_LT.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime -f
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US

apt install --yes dosfstools
mkdosfs -F 32 -s 1 -n EFI ${DISK}-part1
mkdir /boot/efi
echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part1) /boot/efi vfat defaults 0 0 >> /etc/fstab
mount /boot/efi

mkdir /boot/efi/grub /boot/grub
echo /boot/efi/grub /boot/grub none defaults,bind 0 0 >> /etc/fstab
mount /boot/grub

apt install --yes grub-pc linux-image-generic zfs-initramfs zsys
apt remove --purge os-prober -y

cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

grub-probe /boot
apt install dropbear-initramfs -y
#upload RSA autohorized key to /etc/dropbear/authorized_keys
sed -i "s/#DROPBEAR_OPTIONS=/DROPBEAR_OPTIONS=\"-c \/bin\/unlock -p 4748 -s -j -k -I 60\"/" /etc/dropbear-initramfs/config
echo 'ssh-rsa AAAAB THERE IS YOUR RSA PUBLIC KEY FOR SYSTEM UNLOCKING VIA SSH' > /etc/dropbear-initramfs/authorized_keys
chmod 600 /etc/dropbear-initramfs/authorized_keys
wget https://raw.githubusercontent.com/Seneliux/Ubuntu-ZFS-native-encryption/master/scripts/unlock -O /usr/share/cryptsetup/initramfs/bin/unlock
wget https://raw.githubusercontent.com/Seneliux/Ubuntu-ZFS-native-encryption/master/scripts/crypt_unlock -O /usr/share/initramfs-tools/hooks/crypt_unlock
update-initramfs -k all -c

#nano /etc/default/grub
# Add init_on_alloc=0  to: GRUB_CMDLINE_LINUX. Addtional - to disable ipv6: ipv6.disable=1
#remove "splash"
# change "hidden" to "menu": GRUB_TIMEOUT_STYLE=menu
# change GRUB_TIMEOUT=0 to 5.
update-grub
grub-install $DISK


mkdir /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/bpool
touch /etc/zfs/zfs-list.cache/rpool
ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
# After this wait a little bit
zed -F &

# Must be not empty
cat /etc/zfs/zfs-list.cache/bpool
cat /etc/zfs/zfs-list.cache/rpool

sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/bpool
sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/rpool


passwd -l root # or passwd if have not copet SSH authorized_keys
#set port, root login permissions, etc:
nano /etc/ssh/sshd_config

# First reboot
exit
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | \
    xargs -i{} umount -lf {}
zpool export -a
reboot

# Touble
# If not found rpool (initrd promp), import:
zpool import -f -R / rpool
zpool import -f -R / bpool
exit


#cryptsetup: ERROR: Couldn't resolve device rpool/ROOT/
# cryptsetup: WARNING: Couldn't determine root device
# This already fixed in the cryptesetup 2.3.3
apt install build-essential --no-install-recommends -y
cd /usr/share/initramfs-tools/hooks/
wget https://raw.githubusercontent.com/Seneliux/Ubuntu-ZFS-native-encryption/master/scripts/patch
patch -u cryptroot -i patch
chmod -x cryptroot.orig
