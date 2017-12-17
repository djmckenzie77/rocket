#!/bin/bash
# kill all applications RPi-side
sudo killall -q raspivid
sudo killall -q netcat
# creates ftee bin
gcc ftee.c -o ftee
# start streaming to PC
video_out="video${REMOTE_DATE}.h264"
netcat_log="netcat${REMOTE_DATE}.log"
mkfifo netcat_fifo
raspivid -t 0 -w 1920 -h 1080 -o - | ./ftee netcat_fifo > $video_out &
netcat -v 192.168.0.101 5000 < netcat_fifo &> $netcat_log &
