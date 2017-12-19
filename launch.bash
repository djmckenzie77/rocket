#!/bin/bash

# remote server
current_date=$(date '+_%Y%m%d_%H%M%S')
remote_ssh="pi@192.168.0.100"
remote_script="remote.bash"
remote_dir="rocket"
multipipe="ftee"
fps="30"

function clean_host {
    # kill all applications PC-side
    sudo killall -q netcat
    sudo killall -q mplayer
    # launch iptables, netcat and mplayer
    sudo netfilter-persistent reload
}

function clean_remote {
    ssh $remote_ssh << EOF
        rm -f ${remote_dir}/${remote_script}
        rm -f ${remote_dir}/${multipipe}.c
        rm -f ${remote_dir}/${multipipe}
        rm -f ${remote_dir}/netcat_fifo
        sudo killall raspivid 
        sudo killall netcat
EOF
}

clean_host
clean_remote
netcat -l -p 5000 | mplayer -vf scale -zoom -xy 1280 -fps $fps -cache-min 50 -cache 1024 - &
# copy remote files to RPi
scp $remote_script $remote_ssh:~/${remote_dir}
scp ${multipipe}.c $remote_ssh:~/${remote_dir}
# set trap for raspivid
trap clean_remote SIGINT
ssh $remote_ssh << EOF
  export REMOTE_DATE=$current_date
  export MULTIPIPE=$multipipe
  export FPS=$fps
  cd $remote_dir
  nohup bash -x remote.bash &> remote${current_date}.log < /dev/null &
EOF
sleep infinity
