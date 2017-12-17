#!/bin/bash

# remote server
current_date=$(date '+_%Y%m%d_%H%M%S')
remote_ssh="pi@192.168.0.100"
remote_script="remote.bash"
remote_ftee_c="ftee.c"
remote_ftee="ftee"

function clean_host {
    # kill all applications PC-side
    sudo killall -q netcat
    sudo killall -q mplayer
    # launch iptables, netcat and mplayer
    sudo netfilter-persistent reload
}

function clean_remote {
    ssh $remote_ssh << EOF
        rm -f $remote_script
        rm -f $remote_ftee_c
        rm -f $remote_ftee
        rm -f ./netcat_fifo
        sudo killall raspivid 
        sudo killall netcat
EOF
}

clean_host
clean_remote
netcat -l -p 5000 | mplayer -vf scale -zoom -xy 1280 -fps 60 -cache-min 50 -cache 2048 - &
# copy remote files to RPi
scp $remote_script $remote_ssh:
scp $remote_ftee_c $remote_ssh:
# set trap for raspivid
trap clean_remote SIGINT
ssh $remote_ssh << EOF
  export REMOTE_DATE=$current_date
  nohup bash -x remote.bash &> remote${current_date}.log < /dev/null &
EOF
sleep infinity
