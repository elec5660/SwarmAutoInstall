#!/usr/bin/env bash
echo "Sourceing..."
source /opt/ros/kinetic/setup.bash
source /home/dji/swarm_ws/devel/setup.bash

export ROS_MASTER_URI=http://localhost:11311

LOG_PATH=/home/dji/swarm_log/`date +%F_%T`
CONFIG_PATH=/home/dji/SwarmAutoInstall/config

source $CONFIG_PATH/autostart_config.sh  

if [ $SWARM_START_MODE -ge 0 ]
then
    mkdir -p $LOG_PATH
    rm /home/dji/swarm_log_lastest
    ln -s $LOG_PATH /home/dji/swarm_log_lastest
    
    echo "Start ros core"
    roscore &> $LOG_PATH/log_roscore.txt &
    #Sleep 5 wait for core
    sleep 5
    
    echo "Will start camera"
    export START_CAMERA=1
    export START_UWB_STUFF=0
    export START_VO_STUFF=0
    export START_CONTROL=0
    export START_CAMERA_SYNC=0

    if [ $SWARM_START_MODE -ge 1 ]
    then
        echo "Will start VO"
        export START_VO_STUFF=1
        export START_CAMERA_SYNC=1
    fi

    if [ $SWARM_START_MODE -ge 2 ]
    then
        echo "Will start UWB"
        export START_UWB_STUFF=1
    fi

    if [ $SWARM_START_MODE -ge 3 ]
    then
        echo "Will start Control"
        export START_CONTROL=1
    fi
fi



if [ $START_CAMERA -eq 1 ]
then
    echo "Start Camera in unsync mode"
    roslaunch swarm_vo_fuse stereo.launch is_sync:=false config_path:=$CONFIG_PATH/camera_config.yaml &> $LOG_PATH/log_camera.txt &
    PG_PID=$!
    if [ $START_CAMERA_SYNC -eq 1 ]
    then
        sleep 10
        kill -9 $PG_PID
        echo "Start camera in sync mode"
        roslaunch swarm_vo_fuse stereo.launch is_sync:=true config_path:=$CONFIG_PATH/camera_config.yaml &>> $LOG_PATH/log_camera.txt &
    fi
fi

if [ $START_VO_STUFF -eq 1 ]
then
    echo "Enable chicken blood mode"
    /home/dji/jetson_clocks.sh
    roslaunch djisdkwrapper sdk.launch &> $LOG_PATH/log_sdk.txt &
    echo "sleep 10 for djisdk boot up"    
    sleep 10
    rosrun swarm_vo_fuse swarm_tx2_helper.py
    roslaunch vins_estimator dji_stereo.launch config_path:=$CONFIG_PATH/dji_stereo/dji_stereo.yaml &> $LOG_PATH/log_vo.txt &
fi
    
if [ $START_UWB_STUFF -eq 1 ]
then
    roslaunch swarm_vo_fuse swarm_vo_fuse.launch bag_path:="$LOG_PATH" &> $LOG_PATH/log_swarm.txt &
fi

if [ $START_CONTROL -eq 1 ]
then
    #Should sleep 15 for controller
    sleep 15
    /home/dji/SwarmAutoInstall/start_controller.sh &> $LOG_PATH/log_contoller.txt &
fi

