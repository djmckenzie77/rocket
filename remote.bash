#!/bin/bash

# kill all applications RPi-side
sudo killall -q raspivid
sudo killall -q netcat

# raspivid options
raspivid_bin="/home/pi/raspberry/build/bin/raspivid"
raspivid_log="raspivid${REMOTE_DATE}.log"
# -br = brightness [0 to 100] -co = contrast [-100 to 100]; -sh = sharpness [-100 to 100]
raspivid_opt="-md 5 -fps $FPS"

# raspivid |-> FIFO (non-blocking)
#          |-> $video_out
mkfifo netcat_fifo
video_out="video${REMOTE_DATE}.h264"
$raspivid_bin -t 0 $raspivid_opt -o $video_out -o2 netcat_fifo &> $raspivid_log &

# FIFO (non-blocking) -> netcat -> receiver
netcat_log="netcat${REMOTE_DATE}.log"
mbuffer_log="mbuffer${REMOTE_DATE}.log"
cat netcat_fifo | mbuffer -s 2k 2> $mbuffer_log | netcat -v 192.168.0.101 5000 &> $netcat_log &
