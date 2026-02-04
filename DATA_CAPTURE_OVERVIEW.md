# pika_ros Data Capture System Overview

This document provides a comprehensive overview of the data capture infrastructure in pika_ros for robotic teleoperation and imitation learning data collection.

## Table of Contents
- [Overview](#overview)
- [Pose Tracking (libsurvive)](#pose-tracking-libsurvive)
- [Camera System](#camera-system)
- [Data Formats](#data-formats)
- [ROS Node Architecture](#ros-node-architecture)
- [Data Flow](#data-flow)
- [Configuration](#configuration)
- [Complete ROS Topics Reference](#complete-ros-topics-reference)
- [Key File Locations](#key-file-locations)

---

## Overview

The pika_ros data capture system is designed for collecting synchronized multi-modal sensor data for robotic manipulation tasks. It supports various robot configurations:

| Configuration | Description |
|---------------|-------------|
| `single_pika` | Single arm with depth + fisheye camera |
| `multi_pika` | Dual arms (left/right) with multiple cameras |
| `multi_pika_helmet` | Dual arms + helmet-mounted camera and IMU |
| `aloha` | ALOHA teleoperator with master/puppet arms |
| `single_pika_teleop` | Single arm teleoperation setup |

---

## Pose Tracking (libsurvive)

### Architecture
- **libsurvive**: Open-source SteamVR/HTC Vive tracking library (prebuilt `libsurvive.so`)
- **pika_locator**: ROS 2 wrapper package (prebuilt, source not included)
- **No sensor fusion**: IMU and Vive tracking are separate data streams

### Nodes
| Node | Purpose |
|------|---------|
| `pika_single_locator_node` | Single HTC Vive tracker |
| `pika_double_locator_node` | Dual trackers (left/right hands) |
| `three_locator_node` | Triple trackers (left, right, helmet) |

### Parameters
```yaml
dist_limit: 0.2      # Distance filtering (m)
angle_limit: 0.2     # Angle filtering (rad)
linear_limit: 5.0    # Linear velocity limit (m/s)
angular_limit: 20.0  # Angular velocity limit (deg/s)
publish_rate: 100.0  # Hz
```

### Calibration
```bash
./survive-cli --force-calibrate
```
Calibration data stored in `~/.config/libsurvive/`

---

## Camera System

### RealSense Depth Cameras
- **Driver**: Standard Intel `realsense2_camera` driver (v4.55.1)
- **Location**: `src/realsense-ros/`
- **Streams**: Color (RGB8), Depth (Z16), Aligned depth, Point cloud

### USB/Fisheye Cameras
- **Driver**: Custom Python wrapper using OpenCV VideoCapture
- **Location**: `src/sensor_tools/scripts/usb_camera.py`
- **Features**:
  - Configurable resolution (default 640x480 @ 30fps)
  - MJPEG codec support
  - CameraInfo publication
  - TF frame broadcasting

---

## Data Formats

### Raw Directory Structure (Primary)
```
episode{N}/
├── arm/
│   ├── endPose/{name}/*.json       # End effector poses
│   └── jointState/{name}/*.json    # Joint angles
├── camera/
│   ├── color/{name}/*.jpg          # RGB images
│   ├── depth/{name}/*.png          # 16-bit depth maps
│   └── pointCloud/{name}/*.pcd     # Point clouds (PCL format)
├── gripper/
│   └── encoder/{name}/*.json       # Gripper encoder data
├── imu/
│   └── 9axis/{name}/*.json         # IMU sensor data
├── localization/
│   └── pose/{name}/*.json          # 6DOF poses
├── robotBase/
│   └── vel/{name}/*.json           # Odometry/velocity
└── instructions.json               # Task instructions
```

**File naming**: Unix timestamp with microsecond precision (e.g., `1714373556.409885.png`)

### Supported Export Formats

| Format | Scripts | Use Case |
|--------|---------|----------|
| **Raw directory** | `dataCapture.cpp` | Native storage |
| **MCAP** | `record_mcap.py`, `aloha_data_to_mcap.py` | ROS 2 bag format |
| **HDF5** | `data_to_hdf5.py` | ML training/analysis |
| **LeRobot** | `hdf5_to_lerobot.py` | Training framework |

### instructions.json Format
```json
{
  "full-instructions": ["instruction text 1", "instruction text 2"],
  "segment-instructions": [
    {
      "start_time": 1234567890.123,
      "end_time": 1234567895.456,
      "instructions": ["instruction for this segment"]
    }
  ]
}
```

---

## ROS Node Architecture

### Core Data Capture Nodes

| Node | Language | Purpose |
|------|----------|---------|
| `data_tools_dataCapture` | C++ | Real-time multi-sensor capture to disk |
| `record_mcap.py` | Python | MCAP bag recording with monitoring |
| `data_sync.py` | Python | Timestamp-based multi-modal synchronization |
| `compress_camera.py` | Python | Real-time image compression |

### Custom Message Types (`data_msgs`)

**Gripper.msg**
```
std_msgs/Header header
float64 angle
float64 distance
float64 effort
float64 velocity
bool enable
bool set_zero
bool error
float64 voltage
float64 driver_temp
float64 motor_temp
float64 bus_current
string status
```

**Instruction.msg**
```
std_msgs/Header header
string text
builtin_interfaces/Time start_stamp
builtin_interfaces/Time end_stamp
```

**CaptureStatus.msg**
```
string[] topics
int32[] count_in_seconds
float32[] frequencies
bool fail
bool quit
bool wait
```

### Threading Model (dataCapture.cpp)
- Separate subscription threads per sensor type
- `BlockingDeque<T>` for thread-safe message queuing
- Producer-consumer pattern decouples acquisition from disk I/O

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         LIVE SENSORS                            │
├─────────────┬─────────────┬─────────────┬─────────────┬────────┤
│  RealSense  │   Fisheye   │  libsurvive │   Gripper   │  IMU   │
│   Cameras   │   Cameras   │   Tracker   │   Encoder   │ Sensor │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴───┬────┘
       │             │             │             │          │
       ▼             ▼             ▼             ▼          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ROS 2 TOPICS                             │
│  /camera/color/image_raw    /pika_pose    /gripper/data         │
│  /camera/aligned_depth...   /pika_pose_l  /imu/data             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
       ┌────────────┐   ┌────────────┐   ┌────────────┐
       │dataCapture │   │record_mcap │   │ ros2 bag   │
       │   (C++)    │   │   (Py)     │   │  record    │
       └─────┬──────┘   └─────┬──────┘   └─────┬──────┘
             │                │                │
             ▼                ▼                ▼
       ┌────────────┐   ┌────────────┐   ┌────────────┐
       │    Raw     │   │   MCAP     │   │  ROS Bag   │
       │ Directory  │   │   File     │   │   File     │
       └─────┬──────┘   └────────────┘   └────────────┘
             │
             ▼
       ┌────────────┐
       │ data_sync  │  (30ms tolerance)
       └─────┬──────┘
             │
             ▼
       ┌────────────┐
       │data_to_hdf5│
       └─────┬──────┘
             │
             ▼
       ┌────────────┐
       │    HDF5    │
       │   File     │
       └─────┬──────┘
             │
             ▼
       ┌────────────┐
       │  LeRobot   │  (Training)
       └────────────┘
```

### MCAP Recording
- **Native real-time**: `record_mcap.py` subscribes to topics and writes directly to MCAP
- **Post-processing**: `aloha_data_to_mcap.py` converts existing raw data to MCAP
- **Frequency monitoring**: 1Hz status reports, timeout-based failure detection

### Data Synchronization
- Algorithm: Finds closest timestamps across all sensors within `timeDiffLimit` (default 30ms)
- Output: `sync.txt` file in each sensor directory with aligned filenames
- Launch: `ros2 launch data_tools run_data_sync.launch.py type:=single_pika`

---

## Configuration

### YAML Configuration Files
Located in `src/data_tools/config/`:

| File | Configuration |
|------|---------------|
| `single_pika_data_params.yaml` | Single arm robot |
| `multi_pika_data_params.yaml` | Dual arm robots |
| `multi_pika_helmet_data_params.yaml` | Dual arms + helmet IMU |
| `aloha_data_params.yaml` | ALOHA teleoperator |

### Example Configuration
```yaml
/**:
  ros__parameters:
    dataInfo:
      camera:
        color:
          names: ['pikaDepthCamera', 'pikaFisheyeCamera']
          parentFrames: ['camera_link', 'camera_fisheye_link']
          topics: ['/camera/color/image_raw', '/camera_fisheye/color/image_raw']
          configTopics: ['/camera/color/camera_info', '/camera_fisheye/color/camera_info']
        depth:
          names: ['pikaDepthCamera']
          topics: ['/camera/aligned_depth_to_color/image_raw']

      localization:
        pose:
          names: ['pika']
          topics: ['/pika_pose']

      gripper:
        encoder:
          names: ['pika']
          topics: ['/gripper/data']
```

### Built-in Frequency Monitoring
The `record_mcap.py` node provides real-time monitoring:
```
--- 42 ---
/camera/color/image_raw: 30 / 1260 (30.0HZ)
/camera_fisheye/color/image_raw: 28 / 1176 (28.0HZ) < (30HZ) --- [check]
/gripper/data: 100 / 4200 (100.0HZ)
```

Features:
- Per-topic frame counts and frequencies
- Configurable expected Hz per sensor
- Timeout-based failure detection (default 2 seconds)
- `CaptureStatus` message publication for external monitoring

---

## Complete ROS Topics Reference

### Camera Topics - RealSense Depth

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/camera/color/image_raw` | `sensor_msgs/Image` | Color image stream |
| `/camera/color/camera_info` | `sensor_msgs/CameraInfo` | Color camera calibration |
| `/camera/aligned_depth_to_color/image_raw` | `sensor_msgs/Image` | Depth aligned to color frame |
| `/camera/aligned_depth_to_color/camera_info` | `sensor_msgs/CameraInfo` | Aligned depth calibration |
| `/camera/depth/image_rect_raw` | `sensor_msgs/Image` | Rectified depth image |
| `/camera/depth/color/points` | `sensor_msgs/PointCloud2` | 3D colored point cloud |
| `/camera/accel/sample` | `sensor_msgs/Imu` | RealSense IMU acceleration |

**Multi-camera namespace variants:** `/camera_l/`, `/camera_r/`, `/camera_h/`, `/camera_f/`, `/camera_down/`

### Camera Topics - USB/Fisheye

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/camera_fisheye/color/image_raw` | `sensor_msgs/Image` | Fisheye image stream |
| `/camera_fisheye/color/camera_info` | `sensor_msgs/CameraInfo` | Fisheye calibration |
| `/camera_rgb/color/image_raw` | `sensor_msgs/Image` | USB RGB camera |

**Multi-camera namespace variants:** `/camera_fisheye_l/`, `/camera_fisheye_r/`, `/camera_fisheye_h/`

### Gripper-Mounted Camera Topics

| Namespace | Topics |
|-----------|--------|
| `/gripper/camera/` | `color/image_raw`, `aligned_depth_to_color/image_raw`, `color/camera_info` |
| `/gripper/camera_l/`, `/gripper/camera_r/` | Left/right gripper depth cameras |
| `/gripper/camera_fisheye_l/`, `/gripper/camera_fisheye_r/` | Left/right gripper fisheye cameras |

### Arm/Manipulator Topics

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/joint_states` | `sensor_msgs/JointState` | General joint states |
| `/joint_states_single` | `sensor_msgs/JointState` | Single arm joint states |
| `/joint_states_gripper` | `sensor_msgs/JointState` | Gripper joint feedback |
| `/joint_states_lift` | `sensor_msgs/JointState` | Lift motor joint states |
| `/piper_FK/urdf_end_pose` | `geometry_msgs/PoseStamped` | Forward kinematics end pose |
| `/piper_FK/urdf_end_pose_orient` | `geometry_msgs/PoseStamped` | FK end pose with orientation |
| `/piper_IK/ctrl_end_pose` | `geometry_msgs/PoseStamped` | Inverse kinematics control input |
| `/piper_IK/receive_end_pose_orient` | `geometry_msgs/PoseStamped` | IK received end pose |
| `/arm_control_status` | `data_msgs/ArmControlStatus` | Arm control status |

**Multi-arm variants:** Append `_l`, `_r` suffixes (e.g., `/piper_FK_l/`, `/piper_IK_r/`)

**ALOHA-specific topics:**
| Topic | Description |
|-------|-------------|
| `/master/joint_left`, `/master/joint_right` | Master arm joint states |
| `/puppet/joint_left`, `/puppet/joint_right` | Puppet arm joint states |
| `/puppet/end_pose_left`, `/puppet/end_pose_right` | Puppet end effector poses |
| `/rm_left/joint_states`, `/rm_right/joint_states` | RM arm joint states |
| `/dh_left/gripper/joint_states`, `/dh_right/gripper/joint_states` | ALOHA gripper joints |

### Gripper Topics

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/gripper/data` | `data_msgs/Gripper` | Gripper encoder (single) |
| `/gripper_l/data`, `/gripper_r/data` | `data_msgs/Gripper` | Left/right gripper encoder |
| `/sensor/gripper/data` | `data_msgs/Gripper` | Sensor-based gripper feedback |
| `/gripper/gripper_l/data`, `/gripper/gripper_r/data` | `data_msgs/Gripper` | Alternate naming |

### Localization/Pose Topics

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/pika_pose` | `geometry_msgs/PoseStamped` | Single robot 6DOF pose (libsurvive) |
| `/pika_pose_l`, `/pika_pose_r` | `geometry_msgs/PoseStamped` | Left/right tracker poses |
| `/pika_pose_h` | `geometry_msgs/PoseStamped` | Helmet tracker pose |
| `/pika_localization_status` | `data_msgs/LocalizationStatus` | Localization accuracy flag |

### IMU Topics

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/helmet/imu/data` | `sensor_msgs/Imu` | Helmet 9-axis IMU |
| `/imu/data` | `sensor_msgs/Imu` | General IMU topic |

### Other Topics

| Topic | Message Type | Description |
|-------|--------------|-------------|
| `/ranger_base_node/odom` | `nav_msgs/Odometry` | Mobile base odometry |
| `/lifter_1/LiftMotorStatePub` | Custom | Lift motor state |
| `/instruction` | `data_msgs/Instruction` | Task instruction text |
| `/tf` | `tf2_msgs/TFMessage` | Dynamic transforms |
| `/tf_static` | `tf2_msgs/TFMessage` | Static transforms |
| `/data_tools_dataCapture/status` | `data_msgs/CaptureStatus` | Recording status |

---

## Key File Locations

### Source Code
| Component | Path |
|-----------|------|
| Data capture (C++) | `src/data_tools/src/dataCapture.cpp` |
| Data sync (C++) | `src/data_tools/src/dataSync.cpp` |
| MCAP recorder | `src/data_tools/scripts/record_mcap.py` |
| Data sync (Python) | `src/data_tools/scripts/data_sync.py` |
| HDF5 converter | `src/data_tools/scripts/data_to_hdf5.py` |
| USB camera driver | `src/sensor_tools/scripts/usb_camera.py` |
| Gripper/IMU driver | `src/sensor_tools/src/serial_gripper_imu.cpp` |
| RealSense driver | `src/realsense-ros/` |

### Configuration
| Type | Path |
|------|------|
| Data capture configs | `src/data_tools/config/*_data_params.yaml` |
| Vive udev rules | `src/sensor_tools/scripts/81-vive.rules` |

### Launch Files
| Purpose | Path |
|---------|------|
| Single sensor | `src/sensor_tools/launch/open_single_sensor.launch.py` |
| Multi sensor | `src/sensor_tools/launch/open_multi_sensor.launch.py` |
| Sensor + gripper | `src/sensor_tools/launch/open_sensor_gripper.launch.py` |
| Data capture | `src/data_tools/launch/run_data_capture.launch.py` |
| MCAP capture | `src/data_tools/launch/run_data_capture_to_mcap.launch.py` |
| Data sync | `src/data_tools/launch/run_data_sync.launch.py` |

### Prebuilt Binaries
| Component | Location |
|-----------|----------|
| pika_locator | `source/install.zip` → `install/pika_locator/` |
| libsurvive | `source/install.zip` → `install/libsurvive/` |

---

## Using Your Own Data Capture

You can use standard `ros2 bag record` if you have the `data_msgs` package sourced:

```bash
# With data_msgs package available
ros2 bag record /camera/color/image_raw /camera/aligned_depth_to_color/image_raw \
    /pika_pose /gripper/data /joint_states -o my_recording
```

**Requirements:**
- `data_msgs` package must be built and sourced for custom messages (`Gripper`, `Instruction`)
- Standard ROS 2 messages work out of the box

**What you lose vs. built-in recorder:**
- No automatic frequency monitoring
- No service-based start/stop control
- No YAML-driven topic configuration
- No automatic type mapping
