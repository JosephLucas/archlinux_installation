#!/usr/bin/env bash

# Set notification location
# https://ubuntuforums.org/showthread.php?t=2214834
# Top Left = 0
# Bottom Left = 1
# Top Right = 2
# Bottom Right = 3
xfconf-query -c xfce4-notifyd -p /notify-location -s 3

# https://unix.stackexchange.com/a/60936
while true ; do
  battery_level=`acpi -b | grep -P -o '[0-9]+(?=%)'`
  if [ $battery_level -le 10 ]
  then
      notify-send "Battery low" "Battery level is ${battery_level}%" --icon=battery
  fi
  sleep 120
done
