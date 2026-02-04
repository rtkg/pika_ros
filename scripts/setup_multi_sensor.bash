#!/bin/bash
# Setup udev rules for 2 PikaSense (sensors)
# Sensor L -> ttyUSB50, video50 (USB hub 1-4)
# Sensor R -> ttyUSB51, video51 (USB hub 1-3)

sudo sh -c 'echo "ACTION==\"add\", KERNELS==\"1-4.4:1.0\", SUBSYSTEMS==\"usb\", MODE:=\"0777\", SYMLINK+=\"ttyUSB50\"" > /etc/udev/rules.d/sensor_serial.rules'
sudo sh -c 'echo "ACTION==\"add\", KERNELS==\"1-3.4:1.0\", SUBSYSTEMS==\"usb\", MODE:=\"0777\", SYMLINK+=\"ttyUSB51\"" >> /etc/udev/rules.d/sensor_serial.rules'

sudo sh -c 'echo "ACTION==\"add\", KERNEL==\"video[0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48]*\", KERNELS==\"1-4.1:1.0\", SUBSYSTEMS==\"usb\", MODE:=\"0777\", SYMLINK+=\"video50\"" > /etc/udev/rules.d/sensor_fisheye.rules'
sudo sh -c 'echo "ACTION==\"add\", KERNEL==\"video[0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48]*\", KERNELS==\"1-3.1:1.0\", SUBSYSTEMS==\"usb\", MODE:=\"0777\", SYMLINK+=\"video51\"" >> /etc/udev/rules.d/sensor_fisheye.rules'

sudo udevadm control --reload-rules && sudo service udev restart && sudo udevadm trigger
               