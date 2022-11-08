#!/bin/bash
# ! /usr/bin/zsh

nh () {
    (nohup "$@" >/dev/null 2>&1 &) > /dev/null 2>&1
}

xrandr -s 1920x1080
xinput set-prop "DELL07E6:00 06CB:76AF Touchpad" "libinput Tapping Enabled" 1
nh tilix -e htop
lutris
