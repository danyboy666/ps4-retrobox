clear

echo '                   ~.                   '
echo '            Ya...___|__..ab.     .   .  '
echo '             Y88b  \88b  \88b   (     ) ' 
echo '              Y88b  :88b  :88b   `.oo'\''  '
echo '              :888  |888  |888  ( (`-'\''  '
echo '     .---.    d88P  ;88P  ;88P   `.`.   '
echo '    / .-._)  d8P-"""|"""'\''-Y8P      `.`. '
echo '   ( (`._) .-.  .-. |.-.  .-.  .-.   ) )'
echo '    \ `---( O )( O )( O )( O )( O )-'\'' / '
echo '     `.    `-'\''  `-'\''  `-'\''  `-'\''  `-'\''  .'\''  '
echo '       `---------------------------'\''    '
echo '##  ##     ##     ######   ##  ##   ##  ##   ##  ##   ######'
echo '### ##    ####        ##   ## ##    ##  ##   ##  ##     ##'
echo '######   ##  ##      ##    ####     ##  ##   ##  ##     ##'
echo '######   ######     ##     ###       ####     ####      ##'
echo '## ###   ##  ##    ##      ####       ##       ##       ##'
echo '##  ##   ##  ##   ##       ## ##      ##       ##       ##'
echo '##  ##   ##  ##   ######   ##  ##     ##       ##       ##'
echo
echo '             Was that ship really necessary? Well, it looks cool at least - feeRnt'
echo
echo

#set -e; # fail on command exit

echo "Setting up cryptmount"
cryptsetup -d /key/eap_hdd_key.bin --cipher=aes-xts-plain64 -s 256 --offset=0 --skip=0 create ps4hdd /dev/sd?13
mkdir /ps4hdd
mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd # will take some time
read -p 'Linux disk image file size in GB (recommended >=50) : ' partsize

_install_OS_list="$(ls /ps4hdd/system/boot | grep "\.tar\." )"  
		
	echo -e "Available distros to install in /ps4hdd/system/boot = \n$_install_OS_list,"
	read -t 120 -p "Please type out the OS you would like to install within 120 seconds."$'\n' _install_OS;
	echo -e "Selected $_install_OS for install. . .\n";


_install_OS_img="$(echo "$_install_OS" | sed -n 's/.tar.*/.img/p')";
echo "_install_OS_img = $_install_OS_img";
if [ -f /ps4hdd/home/"$_install_OS_img" ]; then 
	echo "You seem to already have this OS installed.";
	ls /ps4hdd/home | grep "\.img";
 	echo "Please rename the matching .img file";
 	#return 1; //use this only if you ". ./bin/install..." or "source ./bin/install"
	exit 1;
 fi;

#partsize2="$(bc -lw <<EOF
#1024*1024*1024/512*$partsize
#EOF
#)"    #	This also works. But below is more readable
#echo "partsize2 = $partsize2"

#echo "partsize = $partsize"
partsize2="$(echo "($partsize*1024*1024*1024/4096)/1" | bc)"
#echo "partsize2 = $partsize2"

echo "Creating .img file . . ."
dd if=/dev/zero of="/ps4hdd/home/$_install_OS_img" bs=4096 seek="$partsize2" # creates a sparse img file. Use /dev/zero if you use seek. 
# You can change the size, but ensure it's big enuogh for a distribution
sleep 2;
losetup /dev/loop5 /ps4hdd/home/"$_install_OS_img";

echo "What file system would you like to install? Available options: ext4, ext3, ext2 ..."
#TODO

mkfs.ext4 /dev/loop5 # for installation only, will take some time
mount /dev/loop5 /newroot

echo "Extracting the distro into your .img file"
cd /newroot; tar -xvf /ps4hdd/system/boot/"$_install_OS"; # the main installation happens here, install only

echo "Extraction complete!"
echo

echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"
echo


if [ $$ != 1 ]; then
	echo "Your PID is not 1, this is not being run as init process. switch_root will not work."
	echo "Please do resume-boot, or if 'echo \$\$' = 1, then manually do"
	echo "exec switch_root /newroot /newroot/sbin/init , to to try booting again."
	exit 1;
else 

	echo "Booting arch linux, please wait.." 
	sleep 4;
	exec switch_root /newroot /newroot/sbin/init &
	echo "Attempt 1 failed, trying again."
	sleep 4 &&
	exec switch_root /newroot /newroot/sbin/init &
	echo "Attempt 2 failed, trying again."
	sleep 4 &&
	exec switch_root /newroot /newroot/sbin/init
	echo
	echo
	echo "Booting seems to have failed."
	echo "If Arch does not boot automatically press CTRL + D once, then again, and wait." 
	echo "WARNING: Might freeze your shell."
fi;
