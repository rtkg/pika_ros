# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

# ============================================================
# 1. Base tools (with apt cache mounts)
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    curl gnupg2 lsb-release software-properties-common \
    build-essential cmake git g++ python3 python3-pip \
    vim less htop tmux bash-completion wget

# ============================================================
# 1b. NVIDIA GPU support (CUDA toolkit)
# ============================================================
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    nvidia-utils-535 \
    cuda-toolkit-12-6 \
    cuda-nvcc-12-6

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:

# ============================================================
# 2. ROS2 Jazzy repository and installation
# ============================================================
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    ros-jazzy-ros-core \
    ros-jazzy-cv-bridge \
    ros-jazzy-image-transport \
    ros-jazzy-pcl-conversions \
    ros-jazzy-pcl-msgs \
    ros-jazzy-tf2-geometry-msgs \
    ros-jazzy-tf2-eigen \
    ros-jazzy-tf2-sensor-msgs \
    ros-jazzy-diagnostic-updater \
    ros-jazzy-rosbag2-storage-mcap \
    python3-colcon-common-extensions \
    python3-rosdep

# ============================================================
# 3. System dependencies (from JAZZY_MIGRATION.md)
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get install -y \
    libjsoncpp-dev libpcap-dev libpcl-dev \
    zlib1g-dev libx11-dev libusb-1.0-0-dev freeglut3-dev \
    liblapacke-dev libopenblas-dev libssl-dev \
    pkg-config libgtk-3-dev libglfw3-dev libgl1-mesa-dev \
    libglu1-mesa-dev libopenvr-dev libcurl4-openssl-dev

# ============================================================
# 4. Build librealsense2 SDK from source (CMake 3.28+ fix)
# ============================================================
WORKDIR /tmp
RUN git clone --depth 1 --branch v2.55.1 https://github.com/IntelRealSense/librealsense.git
WORKDIR /tmp/librealsense/build
RUN cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_EXAMPLES=OFF \
             -DBUILD_GRAPHICAL_EXAMPLES=OFF \
    && make -j$(nproc) \
    && make install \
    && ldconfig
RUN rm -rf /tmp/librealsense

# ============================================================
# 5. Initialize rosdep
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.ros/rosdep,sharing=locked \
    apt-get update && rosdep init && rosdep update

# ============================================================
# 6. Python dependencies
# ============================================================
# Pin numpy<2 for cv_bridge compatibility (ROS2 Jazzy requires numpy 1.x)
# Use --ignore-installed to bypass system numpy conflict
RUN pip3 install --break-system-packages --ignore-installed "numpy<2" opencv-python

# ============================================================
# 7. Build realsense-ros in Docker workspace (baked into image)
# ============================================================
WORKDIR /ros2_docker/src
RUN git clone --depth 1 --branch 4.56.1 https://github.com/IntelRealSense/realsense-ros.git

# Install dependencies for realsense-ros
WORKDIR /ros2_docker
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.ros/rosdep,sharing=locked \
    . /opt/ros/jazzy/setup.sh && \
    apt-get update && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y

# Build realsense-ros
RUN . /opt/ros/jazzy/setup.sh && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# ============================================================
# 8. Setup shell environment
# ============================================================
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "source /ros2_docker/install/setup.bash" >> /root/.bashrc && \
    echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> /root/.bashrc && \
    echo '[ -f /pika_ws/install/setup.bash ] && source /pika_ws/install/setup.bash' >> /root/.bashrc

WORKDIR /pika_ws
