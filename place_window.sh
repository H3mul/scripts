#!/bin/bash

SCREEN=$(echo $DISPLAY | grep -oP "\d*")

SCREEN_W=$(xrandr | grep "Screen $SCREEN" | awk '{print $8}' | grep -oP "\d*")
SCREEN_H=$(xrandr | grep "Screen $SCREEN" | awk '{print $10}' | grep -oP "\d*")
# SCREEN_W=4080
# SCREEN_H=2348

# X_OFFSET=-60
X_OFFSET=0
Y_OFFSET=0

round() {
    n=0
    echo $(printf %.${n}f $(echo "scale=$n;(((10^$n)*$1)+0.5)/(10^$n)" | bc))
};

set_window () {
    W_FACTOR=$1
    H_FACTOR=$2
    RIGHT=$3
    TOP=$4

    echo $RIGHT
    echo $TOP

    W=$(round "$SCREEN_W * $W_FACTOR")
    H=$(round "$SCREEN_H * $H_FACTOR")

    case "$RIGHT" in
        # Center
        -1)
            X=$(round "$SCREEN_W * 0.5 - $W * 0.5")
            ;;
        # Right
        1)
            X=$(round "$SCREEN_W - $W")
            ;;
        # Left
        0)
            X=0
    esac
    case "$TOP" in
        # Center
        -1)
            Y=$(round "$SCREEN_H * 0.5 - $H * 0.5")
            ;;
        # Bottom
        0)
            Y=$(round "$SCREEN_H - $H")
            ;;
        # Top
        1)
            Y=0
    esac

    # [[ $RIGHT == 1 ]] && X=$(round "$SCREEN_W - $W") || X=0
    # [[ $TOP   == 0 ]] && Y=$(round "$SCREEN_H - $H") || Y=0

    [[ $X -ge 0 ]] && REAL_X=$(round "$X + $X_OFFSET") || REAL_X=-1
    [[ $Y -ge 0 ]] && REAL_Y=$(round "$Y + $Y_OFFSET") || REAL_Y=-1

    wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz && \
        wmctrl -r :ACTIVE: -e 0,$REAL_X,$REAL_Y,$W,$H
}

if [ "$1" == "-h" ]; then
    echo "Usage: $0 --align [<r|right> or <l|left>],[<t|top> or <b|bottom>] --size <x-percentage>,<y-percentage>"
    exit
fi

W_FACTOR=0
H_FACTOR=0
RIGHT=-1
TOP=-1

parse_align () {
    case "$1" in
        "l" | "left")
            RIGHT=0
            ;;
        "r" | "right")
            RIGHT=1
            ;;
    esac
}

parse_align () {
    case "$1" in
        "l" | "left")
            RIGHT=0
            ;;
        "r" | "right")
            RIGHT=1
            ;;
    esac
    shift

    case "$1" in
        "t" | "top")
            TOP=1
            ;;
        "b" | "bottom")
            TOP=0
            ;;
    esac
}

parse_size () {
    W_FACTOR=$1
    H_FACTOR=$2
}

while [ "$#" -gt 1 ]; do
    case "$1" in
        "--align")
            shift
            parse_align $@
            shift 2
            ;;
        "--size")
            shift
            parse_size $@
            shift 2
            ;;
    esac
done

set_window "$W_FACTOR" "$H_FACTOR" "$RIGHT" "$TOP"
