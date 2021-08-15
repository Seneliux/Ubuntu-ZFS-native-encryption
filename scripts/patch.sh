diff -Naur a/usr/share/initramfs-tools/hooks/cryptroot b/usr/share/initramfs-tools/hooks/cryptroot
--- a/usr/share/initramfs-tools/hooks/cryptroot	2019-05-22 18:34:12.116097472 +0100
+++ b/usr/share/initramfs-tools/hooks/cryptroot	2019-05-22 20:13:02.159138688 +0100
@@ -72,19 +72,28 @@
             # take the last mountpoint if used several times (shadowed)
             unset -v devnos
             spec="$(printf '%b' "$spec")"
-            resolve_device "$spec" || continue # resolve_device() already warns on error
             fstype="$(printf '%b' "$fstype")"
-            if [ "$fstype" = "btrfs" ]; then
-                # btrfs can span over multiple devices
-                if uuid="$(device_uuid "$DEV")"; then
-                    for dev in "/sys/fs/$fstype/$uuid/devices"/*/dev; do
-                        devnos="${devnos:+$devnos }$(cat "$dev")"
-                    done
-                else
-                    cryptsetup_message "ERROR: $spec: Couldn't determine UUID"
+            if [ "$fstype" = "zfs" ]; then
+                # zfs can span over multiple devices
+                for dev in $(zpool status -L -P | grep -o "/dev/[^ ]*"); do
+                    MAJ="$(printf "%d\n" 0x$(stat -L -c"%t" -- "$dev"))"
+                    MIN="$(printf "%d\n" 0x$(stat -L -c"%T" -- "$dev"))"
+                    devnos="${devnos:+$devnos }$MAJ:$MIN"
+                done
+            else
+                resolve_device "$spec" || continue # resolve_device() already warns on error
+                if [ "$fstype" = "btrfs" ]; then
+                    # btrfs can span over multiple devices
+                    if uuid="$(device_uuid "$DEV")"; then
+                        for dev in "/sys/fs/$fstype/$uuid/devices"/*/dev; do
+                            devnos="${devnos:+$devnos }$(cat "$dev")"
+                        done
+                    else
+                        cryptsetup_message "ERROR: $spec: Couldn't determine UUID"
+                    fi
+                elif [ -n "$fstype" ]; then
+                    devnos="$MAJ:$MIN"
                 fi
-            elif [ -n "$fstype" ]; then
-                devnos="$MAJ:$MIN"
             fi
         fi
     done </proc/mounts
