# README #

This project intends to implement an on-board camera and an IMU for model rocketry. The video and
IMU data are streamed from the RPi to the receiver, which is coded for a machine running Linux.

Gstreamer decodes and shows the video data sent from the RPi. A Python script retrieves the IMU,
altitude and temperature data. They are conveniently displayed in a 3D-model as shown below.

It works with the following hardware:

* Raspberry Pi Zero W (external WiFi adaptor should also be supported)
* AltiMU-10 v5 (previous versions may work adding support to older altimeters)
* Raspberry Pi Camera Module V2

### Quick start ###

The first thing to do is connect your RPi to the camera module and the I2C pins to the AltiMU-10.
These are the pinouts to be connected, supposing SA0 does not need to be driven (single AltiMU):

![][image/rpi_altimu.png]

Before launching the main script, you may need to redefine the variables remote_ip, local_ip,
altimu_port and video_port to match your network parameters in launch.bash.

The script launch.bash should open all processes both in local and remote machines. I always launch
the script using the bash -x command to ease the debug. There are also log files for every
executed binary in both machines.

Available files:

altimu*.tsv -> payload from altiMU-10 board       (local and remote)
video*.h264 -> h264 video from raspivid binary    (remote)
*.log       -> log files for each executed binary (local and remote)

The tsv file is structured as follows:

timestamp  yaw  pitch  roll  acc_x  acc_y  acc_z  mag_x  mag_y  mag_z  altitude  temperature

timestamp in seconds
altitude relative to 1013.25hPa pressure (MSL)
temperature in celsius