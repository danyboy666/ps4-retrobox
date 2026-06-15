#!/bin/sh
clear

echo "Booting arch linux, please wait.." 
mount LABEL=arch /newroot &
sleep 3 &&
exec switch_root /newroot /newroot/sbin/init &
sleep 2 &&
exec switch_root /newroot /newroot/sbin/init &
sleep 2 &&
exec switch_root /newroot /newroot/sbin/init
