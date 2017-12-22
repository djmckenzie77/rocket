#!/bin/bash

# remote server
current_date=$(date '+_%Y%m%d_%H%M%S')
local_ip="192.168.0.101"
remote_ip="192.168.0.100"
remote_ssh="pi@$remote_ip"
remote_script="remote.bash"
remote_dir="rocket"
fps="30"

function clean_host {
    # kill all applications PC-side
    killall -q gst-launch-1.0
    killall -q MinIMU-9-test.py
    killall -q netcat
    # launch iptables, netcat and mplayer
    sudo netfilter-persistent reload
}

function clean_remote {
    ssh $remote_ssh << EOF
        killall -q raspivid
        killall -q raspivid_tee
        killall -q minimu9-ahrs
EOF
}

clean_host
clean_remote
# launch gstreamer
video_port="5000"
gst_log="gst${current_date}.log"
gst-launch-1.0 udpsrc udp://0.0.0.0:$video_port ! h264parse ! avdec_h264 ! videoconvert ! \
	       videoscale ! video/x-raw,width=1280,height=720 ! autovideosink sync=false &> \
               $gst_log &
# launch AltiMU-10 3D-model
altimu_port="5001"
altimu_log="altimu${current_date}.log"
altimu_payload="altimu_payload${current_date}.tsv"
netcat -l -u 0.0.0.0 $altimu_port | python ./externals/altimu10-gui/MinIMU-9-test.py \
					   -o $altimu_payload &> $altimu_log &
# copy remote files to RPi
rsync -tiu $remote_script $remote_ssh:~/${remote_dir}
rsync_tee=$(rsync -tiu raspivid_tee.cpp $remote_ssh:~/${remote_dir})
rsync_altimu=$(rsync -rtiu ./externals/altimu10-ahrs/ $remote_ssh:~/${remote_dir}/altimu10-ahrs/)
rsync_raspberrypi=$(rsync -rtiu ./externals/raspberrypi/ $remote_ssh:~/${remote_dir}/raspberrypi/)
# set trap for raspivid
trap clean_remote SIGINT
ssh $remote_ssh << EOF
  export REMOTE_IP=$local_ip
  export RSYNC_RASPBERRYPI="$rsync_raspberrypi"
  export RSYNC_TEE="$rsync_tee"
  export RSYNC_ALTIMU="$rsync_altimu"
  export REMOTE_DATE=$current_date
  export FPS=$fps
  export VIDEO_PORT=$video_port
  export ALTIMU_PORT=$altimu_port
  cd $remote_dir
  nohup bash -x remote.bash &> remote${current_date}.log < /dev/null &
EOF
sleep infinity
