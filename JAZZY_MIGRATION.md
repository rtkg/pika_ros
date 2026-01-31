# Pika ROS Migration to Ubuntu 24.04 + ROS2 Jazzy

This document details all changes required to migrate the pika_ros package from Ubuntu 22.04/ROS2 Humble to Ubuntu 24.04/ROS2 Jazzy.

## System Information

- **Original Environment**: Ubuntu 22.04 LTS + ROS2 Humble
- **Target Environment**: Ubuntu 24.04 LTS (Noble) + ROS2 Jazzy
- **Python**: 3.12 (Ubuntu 24.04)
- **CMake**: 3.28.3
- **GCC**: 13/14
- **PCL**: 1.14
- **librealsense**: 2.55.1 (built from source)

## Setup

```
# Checkout the ros2 branch
cd pika_ros
git checkout ros2

# Initialize and update git submodules
git submodule update --init --recursive
```

## Summary of Changes

Three main categories of changes were required:
1. **Build System Compatibility**: CMake version and dependency updates
2. **API Updates**: Library API changes between Ubuntu versions
3. **Python Dependencies**: Missing ROS2 build tools

---

## Detailed Changes

### 1. librealsense Build Fix

**Issue**: CMake 3.28+ removed compatibility with old `cmake_minimum_required` versions.

**File**: Building librealsense-2.55.1

**Fix**: Add CMake policy flag during configuration
```bash
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5
```

**Reason**: The bundled librealsense 2.55.1 uses `cmake_minimum_required(VERSION 3.1.0)` which is no longer supported by CMake 3.28+.

---

### 2. cv_bridge Header Migration

**Issue**: ROS2 Jazzy uses the newer `.hpp` header instead of `.h` for cv_bridge.

**Files Modified**:
- `src/data_tools/src/dataCapture.cpp` (line 8)
- `src/data_tools/src/dataSync.cpp` (line 7)
- `src/data_tools/src/dataPublish.cpp` (line 7)

**Change**:
```cpp
// OLD (Humble)
#include <cv_bridge/cv_bridge.h>

// NEW (Jazzy)
#include <cv_bridge/cv_bridge.hpp>
```

**Reason**: cv_bridge 3.3.0+ (used in Jazzy) moved to the `.hpp` header for C++ projects. The realsense2_camera package already handles this with conditional compilation, but data_tools needed manual updates.

---

### 3. PCL API Update

**Issue**: PCL 1.14 (Ubuntu 24.04) renamed the `setFilterLimitsNegative` method.

**File Modified**: `src/data_tools/src/dataCapture.cpp` (line 938)

**Change**:
```cpp
// OLD (PCL < 1.14)
pass.setFilterLimitsNegative(false);

// NEW (PCL 1.14+)
pass.setNegative(false);
```

**Reason**: PCL 1.14 simplified the API naming. The PassThrough filter's method was renamed for consistency.

---

### 5. System Dependency Updates

**Package Replacements**:

| Humble/Ubuntu 22.04 | Jazzy/Ubuntu 24.04 | Reason |
|---------------------|-------------------|--------|
| `python3-pcl` | `libpcl-dev` | Python PCL bindings not available; C++ library is what ROS packages actually need |
| `libatlas-base-dev` | *removed* | Conflicts on Ubuntu 24.04; `libopenblas-dev` provides equivalent functionality |
| `gcc-13` from PPA | *not needed* | Ubuntu 24.04 ships with GCC 13/14 by default |

**Note**: The realsense2_camera package already included Jazzy support in its CMakeLists.txt (lines 173-176), so no changes were needed there.

---

## Build Instructions Summary

### Prerequisites

1. Install librealsense2 SDK:
```bash
cd ~/librealsense-2.55.1
mkdir build && cd build
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5
make -j$(nproc)
sudo make install
```

2. Install system dependencies:
```bash
sudo apt install -y \
  libjsoncpp-dev libpcap-dev libpcl-dev build-essential \
  zlib1g-dev libx11-dev libusb-1.0-0-dev freeglut3-dev \
  liblapacke-dev libopenblas-dev cmake git libssl-dev \
  pkg-config libgtk-3-dev libglfw3-dev libgl1-mesa-dev \
  libglu1-mesa-dev g++ python3-pip libopenvr-dev cutecom \
  libcurl4-openssl-dev
```

3. Install ROS2 Jazzy dependencies:
```bash
sudo apt install -y \
  ros-jazzy-cv-bridge ros-jazzy-image-transport \
  ros-jazzy-pcl-conversions ros-jazzy-pcl-msgs \
  ros-jazzy-tf2-geometry-msgs ros-jazzy-tf2-eigen \
  ros-jazzy-diagnostic-updater ros-jazzy-rosbag2-storage-mcap
```

4. Install Python dependencies:
```bash
pip3 install --user opencv-python
```

### Build Command

```bash
cd ~/ros/pika_ws
source /opt/ros/jazzy/setup.bash
colcon build 
```

---

## Hardware Setup

### USB Permissions

```bash
# Add user to dialout group for serial devices
sudo usermod -aG dialout $USER

# RealSense camera udev rules
sudo cp ~/librealsense-2.55.1/config/99-realsense-libusb.rules /etc/udev/rules.d/

# HTC Vive tracker udev rules
sudo cp ~/ros/pika_ws/src/pika_ros/src/sensor_tools/scripts/81-vive.rules /etc/udev/rules.d/

# Reload udev rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# Log out and back in for group changes to take effect
```

---

## Testing

After building, test each component:

1. **RealSense Camera**:
```bash
source ~/ros/pika_ws/install/setup.bash
ros2 launch realsense2_camera rs_launch.py
```

2. **Sensor Tools**:
```bash
ros2 launch sensor_tools open_single_sensor.launch.py
```

3. **Data Capture**:
```bash
ros2 launch data_tools run_data_capture_to_mcap.launch.py
```

---

## Future Considerations

### Potential Issues on Future Updates
1. **librealsense**: The bundled 2.55.1 may become outdated. Consider using Intel's apt repository for newer versions if camera hardware requires it.

2. **Python 3.12+**: Future Python versions may require additional compatibility fixes if any Python code uses deprecated features.

3. **PCL Updates**: If PCL 1.15+ changes more APIs, additional PassThrough or filter-related code may need updates.

