#!/bin/bash

# compile tools
if [ -n "${RSYNC_RASPBERRYPI}" ]; then
    make -C ./raspberrypi_build/ raspivid -j4
fi

if [ -n "${RSYNC_ALTIMU}" ]; then
    make -C ./altimu10-ahrs
fi

if [ -n "${RSYNC_TEE}" ]; then
    g++ raspivid_tee.cpp -o raspivid_tee -std=c++11  -lpthread
fi

# raspivid options
raspivid_bin="/home/pi/rocket/raspberrypi/build/bin/raspivid"
raspivid_log="raspivid${REMOTE_DATE}.log"
# -br = brightness [0 to 100] -co = contrast [-100 to 100]; -sh = sharpness [-100 to 100]
raspivid_opt="-t 0 -md 5 -fps $FPS -fl -br 60"

# raspivid |-> $video_out (blocking)
#          |-> udp stream (non-blocking)
video_out="video${REMOTE_DATE}.h264"
$raspivid_bin $raspivid_opt -o - | ./raspivid_tee $video_out udp://$REMOTE_IP:$VIDEO_PORT &> \
						  $raspivid_log &

# altimu   |-> $altimu_date (blocking)
#          |-> udp stream (non-blocking)
altimu_bin="/home/pi/rocket/altimu10-ahrs/minimu9-ahrs"
altimu_log="altimu${REMOTE_DATE}.log"
altimu_data="altimu${REMOTE_DATE}.tsv"
$altimu_bin --output euler --output-file $altimu_data \
   	    --output-file-nb udp://$REMOTE_IP:$ALTIMU_PORT &> $altimu_log
