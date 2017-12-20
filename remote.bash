#!/bin/bash

# raspivid options
raspivid_bin="/home/pi/raspberry/build/bin/raspivid"
raspivid_log="raspivid${REMOTE_DATE}.log"
# -br = brightness [0 to 100] -co = contrast [-100 to 100]; -sh = sharpness [-100 to 100]
raspivid_opt="-md 5 -fps $FPS"

# raspivid |-> $video_out (blocking)
#          |-> udp stream (non-blocking)
video_out="video${REMOTE_DATE}.h264"
$raspivid_bin -t 0 $raspivid_opt -o $video_out -o2 udp://192.168.0.101:$VIDEO_PORT &> \
	      $raspivid_log &

# altimu   |-> $altimu_date (blocking)
#          |-> udp stream (non-blocking)
altimu_log="altimu${REMOTE_DATE}.log"
altimu_data="altimu${REMOTE_DATE}.tsv"
minimu9-ahrs --output euler --output-file $altimu_data \
	     --output-file-nb udp://192.168.0.101:$ALTIMU_PORT &> $altimu_log
