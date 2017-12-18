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
mkfifo netcat_fifo
raspivid -t 0 -md 5 -fps $FPS -o - | ./${MULTIPIPE} netcat_fifo > $video_out &
cat netcat_fifo | mbuffer --direct -t -s 2k 2> $mbuffer_log | netcat -v 192.168.0.101 5000 &> $netcat_log &
