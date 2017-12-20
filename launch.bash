#!/bin/bash

# remote server
current_date=$(date '+_%Y%m%d_%H%M%S')
remote_ssh="pi@192.168.0.100"
remote_script="remote.bash"
remote_dir="rocket"
fps="30"

function clean_host {
    # kill all applications PC-side
    killall -q gst-launch-1.0
    killall -q MinIMU-9-test.py
    # launch iptables, netcat and mplayer
    sudo netfilter-persistent reload
}

function clean_remote {
    ssh $remote_ssh << EOF
        rm -f ${remote_dir}/${remote_script}
        killall -q raspivid 
        killall -q minimu9-ahrs
        killall -q netcat
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
scp $remote_script $remote_ssh:~/${remote_dir}
# set trap for raspivid
trap clean_remote SIGINT
ssh $remote_ssh << EOF
  export REMOTE_DATE=$current_date
  export FPS=$fps
  export VIDEO_PORT=$video_port
  export ALTIMU_PORT=$altimu_port
  cd $remote_dir
  nohup bash -x remote.bash &> remote${current_date}.log < /dev/null &
EOF
sleep infinity
