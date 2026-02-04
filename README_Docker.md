# Docker Setup

## Prerequisites

- Docker installed on host
- X11 (for GUI applications like rviz2)

## Host Setup (One-time)

### USB/udev Rules

The Vive tracker udev rules must be installed on the **host** (not inside Docker):

```bash
sudo cp scripts/81-vive.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

If the wireless receiver is already plugged in, unplug and replug it after this step.

## Build

```bash
make docker_build
```

Builds the `pika_ros_<username>:latest` image.

## Run

```bash
make docker_run
```

Starts an interactive container with:
- `src/` mounted from host for development
- `install/` pre-built inside the image
- Network and device access via `--privileged` and `--network=host`

### Attach to Running Container

```bash
make docker_exec
```

Opens a new shell in an already running container.

## Libsurvive Calibration

### Calibrate Lighthouses

Run this inside the container to calibrate the lighthouse positions:

```bash
cd ~/pika_ros/install/libsurvive/bin && ./survive-cli --force-calibrate
```

Keep the tracker stationary during calibration. The terminal should show no positioning errors when calibration completes successfully.

### Verify Calibration

To verify calibration is working and stream raw observations:

```bash
cd ~/pika_ros/install/libsurvive/bin && ./survive-cli --use-raw-obs 1 --show-raw-obs 1 --record-stdout 1
```

You should see continuous pose data streaming when the tracker is in view of the lighthouses.
