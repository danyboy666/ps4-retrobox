#!/bin/sh
echo -e "\n\n\n\n"

mkdir /temp
mkdir /backup


PS3="Select which disk has the distribution to install: "; 
partitions=()

while IFS= read -r newline; do
	partitions+=("$newline")
done < "$(lsblk | awk '{sub(/^.*s/, "s", $1); if($1 ~ /^s/) print $1}')"
partitions+=("Don't know which device to select? Quit to do an automatic search.")

select part in "${partitions[@]}"
do
	case $part in
		"Don't know which device to select? Quit to do an automatic search.")
			echo "Will do automatic search. . ."
			__auto_search=1
			break
			;;
		"$part")
			echo "Searching "$part" for the installation files."
			break
			;;
		*) echo "Unknown option: "$REPLY""
	esac
done


echo "Try to find the right usb"
for x in a b c d e f g h i j k
do
	device="/dev/sd"$x
    mount $device"1" /temp
    if [ $? = 0 ]; then
		if [ -e /temp/bzImage ] && [ -e /temp/initramfs.cpio.gz ] && [ -e /temp/arch.tar.xz ]; then
			echo "Device $device has the the kernel (bzImage), initramfs and distro.tar.xz/gz to install arch linux"
			break;
		fi
		umount $device"1"
	fi
	if [ $x = "k" ]; then
		echo "ERROR! No valid usb device found! Try remove, reinsert the usb device and run again install-arch.sh"
		echo "If the error persist probably your usb device is not formatted correctly or some fileq are missing or corrupted" 
		exit
	fi
done

sizeusb=$(fdisk -l | grep -i "Disk $device" | awk '{print $3}')
mu=$(fdisk -l | grep -i "Disk $device" | awk '{print $4}')
sizeusb=$(echo $sizeusb | awk -F',' '{print $1}')
mu=$(echo $mu | awk -F',' '{print $1}')

echo "Size usb device: $sizeusb $mu"
if [ $sizeusb -lt 12 ]; then
	echo "Not enough space on the usb device, please insert one usb with almost 12GB of free space and run again install-arch.sh"
	exit
fi

echo "Created by @NazkyYT. Move arch, the bzImage and the initramfs to /backup"

# 1 GB RAM limit

if [ $? -ne  0 ]; then
	echo "No enough space in RAM availble!"
	echo "Go to 'http://ps4xploit.zd.lu' and choose 'Linux 1GB'"
	exit
fi

# Thanks to hippie68 for the fix:

total_size=$(fdisk -lu "$device" | grep -i "Disk $device" | awk '{print $5}')
total_sectors=$(fdisk -lu "$device" | grep -i "Disk $device" | awk '{print $7}')
sector_size=$(expr $total_size / $total_sectors)
fat32_sector_count=$(expr 104857600 / $sector_size) # 100 MiB
fat32_first_sector=2048
fat32_last_sector=$(expr $fat32_first_sector + $fat32_sector_count - 1)
ext4_first_sector=$(expr $fat32_last_sector + 1)
ext4_last_sector=$(expr $total_sectors - 1)

#Move files

mv -v /temp/initramfs.cpio.gz /backup

if [ $? -ne  0 ]; then
	exit
fi
echo

echo "initramfs.cpio.gz moved"
echo

mv -v /temp/bzImage /backup

if [ $? -ne  0 ]; then
	exit
fi

echo "bzImage moved"
echo

mv -v /temp/arch.tar.xz /backup

if [ $? -ne  0 ]; then
	exit
fi

echo "arch.tar.xz moved"
echo


umount $device"1"

echo "Create a FAT32 and an ext4 partition:"
echo
echo "Total size: $total_size"
echo "Total sectors: $total_sectors"
echo "Sector size: $sector_size"
echo "FAT32 partition sector count: $fat32_sector_count"
echo "FAT32 partition first sector: $fat32_first_sector"
echo "FAT32 partition last sector: $fat32_last_sector"
echo "ext4 partition first sector: $ext4_first_sector"
echo "ext4 partition last sector: $ext4_last_sector"
echo

(
echo "o" #fdisk can't write device with disklabel GPT
echo "d"
echo "n"
echo "p"
echo "1"
echo "$fat32_first_sector"
echo "$fat32_last_sector"
echo "n"
echo "p"
echo "2"
echo "$ext4_first_sector"
echo "$ext4_last_sector"
echo "w"
echo "q"
) | fdisk -u $device

echo "Format fat32 partition"
mkfs.vfat $device"1"

echo "Remount the fat32 partition and copy in the initramfs and bzImage"
mount $device"1" /temp
mv -v /backup/initramfs.cpio.gz /temp
mv -v /backup/bzImage /temp
umount $device"1"

echo "Format the ext4 partition to arch and mount it to /newroot"
mke2fs-new -t ext4 -F -L arch -O ^has_journal $device"2" 
mount $device"2" /newroot

echo "Installing arch linux, please wait, DON'T REMOVE THE USB DEVICE OR SHUTDOWN THE PS4!"
sleep 5

echo "Extract backup of arch to /newroot"
tar -xvpJf /backup/arch.tar.xz -C /newroot --numeric-owner

echo "Arch linux installed with success! Clean some garbage.."
rm /backup/*
rm -R /newroot/lost+found

echo "Add eap key and edid.."
cp /key/eap_hdd_key.bin /newroot/etc/cryptmount
cp /lib/firmware/edid/my_edid.bin /newroot/lib/firmware/edid

echo "Booting arch linux, please wait.." 
exec start-arch.sh
