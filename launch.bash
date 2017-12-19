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
    # launch iptables, netcat and mplayer
    sudo netfilter-persistent reload
}

function clean_remote {
    ssh $remote_ssh << EOF
        rm -f ${remote_dir}/${remote_script}
        killall raspivid 
EOF
}

clean_host
clean_remote
gst-launch-1.0 udpsrc udp://0.0.0.0:5000 ! h264parse ! avdec_h264 ! videoconvert ! \
	       videoscale ! video/x-raw,width=1280,height=720 ! autovideosink sync=false &
# copy remote files to RPi
scp $remote_script $remote_ssh:~/${remote_dir}
# set trap for raspivid
trap clean_remote SIGINT
ssh $remote_ssh << EOF
  export REMOTE_DATE=$current_date
  export FPS=$fps
  cd $remote_dir
  nohup bash -x remote.bash &> remote${current_date}.log < /dev/null &
EOF
sleep infinity
