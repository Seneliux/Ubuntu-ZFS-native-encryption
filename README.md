# Ubuntu server on ZFS, encrypted /root, remote unlock

WARNNG: DO NOT BLINDLY COPY ALL! Do it line by line.

First use install_UBUNTU_zfs.sh, then  configure_UBUNTU_zfs.sh. 

This installation works on BIOS system. Installed from Debian live CD, because VPS do not allow to add custom ISO and limited to 3 images.
Eaasy to adopt to the EFI system. Consult [OpenZFS How-to](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html)

Last steps like user creation, etc., please look OpenZFS docs (link is in Source list)

Sources
[OpenZFS docs](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2020.04%20Root%20on%20ZFS.html)  
cryptsetup error patch from [launcpad bugs](https://bugs.launchpad.net/debian/+source/cryptsetup/+bug/1830110)  
[Remote unlocking native encrypted ZFS](https://github.com/dynerose/Remote-unlock-native-ZFS)  

Later....
