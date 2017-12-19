#!/bin/bash
# kill all applications RPi-side
sudo killall -q raspivid
sudo killall -q netcat
# creates multipipe bin
gcc ${MULTIPIPE}.c -o ${MULTIPIPE}
# start streaming to PC
video_out="video${REMOTE_DATE}.h264"
netcat_log="netcat${REMOTE_DATE}.log"
mbuffer_log="mbuffer${REMOTE_DATE}.log"
raspivid_bin="/home/pi/raspberry/build/bin/raspivid"
mkfifo netcat_fifo
$raspivid_bin -t 0 -md 5 -fps $FPS -o $video_out -o2 netcat_fifo &
cat netcat_fifo | mbuffer --direct -t -s 2k 2> $mbuffer_log | netcat -v 192.168.0.101 5000 &> $netcat_log &
