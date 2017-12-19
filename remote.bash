#!/bin/bash

# kill all applications RPi-side
sudo killall -q raspivid
sudo killall -q netcat

# raspivid options
raspivid_bin="/home/pi/raspberry/build/bin/raspivid"
raspivid_log="raspivid${REMOTE_DATE}.log"
# -br = brightness [0 to 100] -co = contrast [-100 to 100]; -sh = sharpness [-100 to 100]
raspivid_opt="-md 5 -fps $FPS"

# raspivid |-> $video_out (blocking)
#          |-> udp stream (non-blocking)
video_out="video${REMOTE_DATE}.h264"
$raspivid_bin -t 0 $raspivid_opt -o $video_out -o2 udp://192.168.0.101:5000 &> $raspivid_log &
