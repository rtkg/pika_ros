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

### With GUI Support

```bash
make docker_run_x
```

Same as above, but runs `xhost +local:root` first to allow GUI applications (rviz2, rqt, etc.) to display.
