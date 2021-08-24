# disk formating
apt install --yes -t buster-backports debootstrap
systemctl stop zed
# apend this line with the disk name:
DISK=/dev/disk/by-id/
wipefs --all -f $DISK
sgdisk --zap-all $DISK
sgdisk -n1:1M:+512M -t1:EF00 $DISK
sgdisk -a1 -n5:24K:+1000K -t5:EF02 $DISK
# 2G for boot partition if only use zsys. 
#sgdisk -n3:0:+2G -t3:BE00 $DISK
sgdisk -n3:0:+768M -t3:BE00 $DISK
sgdisk -n4:0:0 -t4:BF00 $DISK
partprobe

# On both pools adjust ashift, and on SSD add autotrim. ashift for old disks 512B sector =9, 4k=12, 8k=13. Not gold rule, it is performance price for capacity and vice versa.
# pools creation
zpool create \
-o cachefile=/etc/zfs/zpool.cache \
-o ashift=9 -d \
-o feature@async_destroy=enabled \
-o feature@bookmarks=enabled \
-o feature@embedded_data=enabled \
-o feature@empty_bpobj=enabled \
-o feature@enabled_txg=enabled \
-o feature@extensible_dataset=enabled \
-o feature@filesystem_limits=enabled \
-o feature@hole_birth=enabled \
-o feature@large_blocks=enabled \
-o feature@lz4_compress=enabled \
-o feature@spacemap_histogram=enabled \
-O acltype=posixacl -O canmount=off -O compression=lz4 \
-O devices=off -O normalization=formD -O atime=off -O xattr=sa \
-O mountpoint=/boot -R /mnt \
bpool ${DISK}-part3

# My machine not supporting feature@log_spacemap, so I disabled. With thisd system booted read-only
zpool create \
-o ashift=9 \
-o feature@log_spacemap=disabled \
-O encryption=aes-256-gcm \
-O keylocation=prompt -O keyformat=passphrase \
-O acltype=posixacl -O canmount=off -O compression=lz4 \
-O dnodesize=auto -O normalization=formD -O atime=off \
-O xattr=sa -O mountpoint=/ -R /mnt \
rpool ${DISK}-part4

# Create filesystem datasets to act as containers:
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

# datasets unique ID. A few symbols. Recommend to add pard of domain name without dots, or computer name
UUID=part_of_domain_name_or_computer-name
# Create filesystem datasets for the root and boot filesystems:
zfs create -o mountpoint=/ -o com.ubuntu.zsys:bootfs=yes -o com.ubuntu.zsys:last-used=$(date +%s) rpool/ROOT/$UUID
zfs create -o mountpoint=/boot bpool/BOOT/$UUID

# Create datasets:
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off rpool/ROOT/$UUID/usr
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off rpool/ROOT/$UUID/var
zfs create rpool/ROOT/$UUID/var/log
zfs create rpool/ROOT/$UUID/var/spool
zfs create -o com.sun:auto-snapshot=false rpool/ROOT/$UUID/var/cache

# USERDATA SEPARATED FROM SYSTEM
zfs create -o canmount=off -o mountpoint=/ rpool/USERDATA
zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/$UUID -o canmount=on -o mountpoint=/root rpool/USERDATA/root_$UUID
chmod 700 /mnt/root
zfs create -o com.ubuntu.zsys:bootfs=no rpool/USERDATA/srv
zfs create -o com.ubuntu.zsys:bootfs=no rpool/USERDATA/opt
zfs create -o com.ubuntu.zsys:bootfs=no rpool/USERDATA/librephotos
zfs create -o com.ubuntu.zsys:bootfs=no -o mountpoint=/etc/letsencrypt rpool/USERDATA/letsencrypt
zfs create -o com.ubuntu.zsys:bootfs=no -o mountpoint=/etc/nginx rpool/USERDATA/nginx
zfs create -o mountpoint=/var/vmail rpool/USERDATA/vmail
zfs create -o mountpoint=/var/www rpool/USERDATA/www
zfs create -o mountpoint=/usr/local rpool/USERDATA/usr_local
zfs create -o mountpoint=/var/lib/mysql rpool/USERDATA/mysql
zfs create -o recordsize=16k -o primarycache=metadata rpool/USERDATA/mysql/mysql-data
zfs create rpool/USERDATA/mysql/mysql-log
zfs create -o canmount=noauto -o mountpoint=/var/lib/postgresql rpool/USERDATA/postgresql
zfs create -o recordsize=32k -o redundant_metadata=most rpool/USERDATA/postgresql/psql-data
zfs create -o recordsize=64k -o redundant_metadata=most rpool/USERDATA/postgresql/psql-wal
zfs create -o mountpoint=/etc/opendkim rpool/USERDATA/opendkim

# install system
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock
debootstrap --include nano,openssh-server,wget,ufw focal /mnt http://archive.ubuntu.com/ubuntu
mkdir /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

# configure system. Set hostname
HOSTNAME=
echo $HOSTNAME > /mnt/etc/hostname
#remove FQDN from the second line if you have not FQDN
echo -e '127.0.0.1\tlocalhost $HOSTNAME
127.0.1.1\tFQDN $HOSTNAME' > /mnt/etc/hosts

echo 'deb http://de.archive.ubuntu.com/ubuntu focal main restricted universe multiverse
deb http://de.archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
deb http://de.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse
' > /mnt/etc/apt/sources.list

echo "vm.swappiness = 1" >> /mnt/etc/sysctl.conf

cat > /mnt/etc/netplan/01-netcfg.yaml << EOF
network:
    ethernets:
        $(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'):
            addresses: [$(ip a | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')/24]
            gateway4: $(ip r | awk '/default/ { print $3 }')
            nameservers:
                addresses: [9.9.9.9]
            dhcp4: no
    version: 2
EOF

# chroot
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys
chroot /mnt /usr/bin/env DISK=$DISK bash --login
