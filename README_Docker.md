# Docker Setup

## Prerequisites

- Docker installed on host
- X11 (for GUI applications like rviz2)

## Build & Run

```bash
make docker_build    # Build image
make docker_run      # Start container
make docker_exec     # Attach to running container
```

## Host Setup (One-time)

### Vive Tracker

```bash
sudo cp scripts/81-vive.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Unplug and replug the wireless receiver after this step.

### PIKA Devices (2 PikaSense + 2 Grippers)

Devices use udev rules based on USB topology. **Keep devices plugged into the same ports after setup.**

1. Find USB paths for each device (plug in one at a time):
   ```bash
   udevadm info -a /dev/ttyUSBX | grep KERNELS | head -3   # Serial port
   udevadm info -a /dev/videoX | grep KERNELS | head -3    # Fisheye camera
   ```

2. Edit setup scripts with discovered KERNELS paths:
   - `scripts/setup_multi_sensor.bash` → ttyUSB50/51, video50/51
   - `scripts/setup_multi_gripper.bash` → ttyUSB60/61, video60/61

3. Edit start scripts with RealSense serial numbers (`rs-enumerate-devices -s`):
   - `scripts/start_multi_sensor.bash`
   - `scripts/start_multi_gripper.bash`

4. Run setup scripts on **host**, then unplug/replug all devices:
   ```bash
   bash scripts/setup_multi_sensor.bash
   bash scripts/setup_multi_gripper.bash
   ls -la /dev/ttyUSB{50,51,60,61} /dev/video{50,51,60,61}  # Verify symlinks
   ```

## Running (Inside Docker)

```bash
# Terminal 1 - Start 2 PikaSense
# Launches: 2x RealSense D405, 2x fisheye cameras, 2x serial IMU, locator, rviz
bash scripts/start_multi_sensor.bash

# Terminal 2 - Start 2 PIKA Grippers
# Launches: 2x RealSense D405, 2x fisheye cameras, 2x serial grippers
bash scripts/start_multi_gripper.bash
```

## Libsurvive Calibration

```bash
# Calibrate lighthouses (keep tracker stationary)
cd ~/pika_ros/install/libsurvive/bin && ./survive-cli --force-calibrate

# Verify calibration
cd ~/pika_ros/install/libsurvive/bin && ./survive-cli --use-raw-obs 1 --show-raw-obs 1 --record-stdout 1
```
