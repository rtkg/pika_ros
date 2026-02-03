# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

# Install system dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    vim \
    less \
    htop \
    tmux \
    net-tools \
    iputils-ping \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    build-essential \
    cmake \
    g++ \
    git \
    python3 \
    python3-pip \
    python3-dev \
    python3-pcl \
    bash-completion \
    unzip \
    pkg-config \
    libssl-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libgtk-3-dev \
    freeglut3-dev \
    libjsoncpp-dev \
    zlib1g-dev \
    libx11-dev \
    libpcap-dev \
    liblapacke-dev \
    libopenblas-dev \
    libatlas-base-dev

# Add ROS2 apt repository
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS2 Humble and additional packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    ros-humble-ros-base \
    ros-humble-sensor-msgs \
    ros-humble-geometry-msgs \
    ros-humble-std-msgs \
    ros-humble-std-srvs \
    ros-humble-nav-msgs \
    ros-humble-visualization-msgs \
    ros-humble-tf2 \
    ros-humble-tf2-ros \
    ros-humble-tf2-geometry-msgs \
    ros-humble-tf2-sensor-msgs \
    ros-humble-tf2-eigen \
    ros-humble-pcl-conversions \
    ros-humble-pcl-msgs \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-image-transport-plugins \
    ros-humble-diagnostic-updater \
    ros-humble-rosbag2 \
    ros-humble-rosbag2-storage-mcap \
    ros-humble-launch-pytest \
    ros-humble-launch-ros \
    ros-humble-rviz2 \
    ros-humble-rqt* \
    python3-colcon-common-extensions \
    python3-rosdep

# Initialize rosdep
RUN rosdep init && rosdep update

# Copy and extract curl and librealsense sources
WORKDIR /tmp/build
COPY source/curl-7.75.0.zip source/librealsense-2.55.1.zip /tmp/build/
RUN unzip curl-7.75.0.zip && unzip librealsense-2.55.1.zip

# Modify external_libcurl.cmake to use correct curl path
RUN sed -i 's|/home/agilex/pika_ros/source/curl-7.75.0|/tmp/build/curl-7.75.0|g' \
    librealsense-2.55.1/CMake/external_libcurl.cmake

# Build librealsense (as per manual: cmake .. && make install)
RUN cd librealsense-2.55.1 && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd /tmp && rm -rf /tmp/build

# Install Python packages
RUN pip3 install \
    numpy \
    scipy \
    opencv-python \
    pyserial \
    transforms3d

# Create pika_ros directory and extract install.zip (as per manual)
RUN mkdir -p /root/pika_ros
COPY source/install.zip /root/pika_ros/
RUN cd /root/pika_ros && \
    unzip install.zip && \
    chmod 777 -R install/ && \
    rm install.zip

# Source ROS Humble and workspace in bashrc (as per manual)
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "source ~/pika_ros/install/setup.bash" >> /root/.bashrc && \
    echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> /root/.bashrc && \
    echo "source /etc/bash_completion" >> /root/.bashrc

# Create python symlink for compatibility
RUN ln -sf /usr/bin/python3 /usr/bin/python

WORKDIR /root/pika_ros
