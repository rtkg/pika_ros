SHELL := /bin/bash
BASE := $(shell pwd)/../..
DOCKER_USER_UID := $(shell id -u)

docker_build:
	docker build -t pika_ros_$(USER):latest .

docker_run:
	touch $(HOME)/.docker_bash_history && \
	docker run -it --rm --network=host --gpus all --privileged \
		--name pika_ros_$(USER) \
		--label "user=$(USER)" \
		--ipc=host \
		-v $(BASE)/src:/pika_ws/src \
		-v $(BASE)/install:/pika_ws/install \
		-v $(BASE)/build:/pika_ws/build \
		-v $(HOME)/.docker_bash_history:/root/.bash_history \
		-v /dev:/dev \
		-w /pika_ws/src/pika_ros \
		-e DISPLAY=$(DISPLAY) \
		-e DOCKER_USER_UID=$(DOCKER_USER_UID) \
		-e QT_X11_NO_MITSHM=1 \
		-v /tmp/.X11-unix:/tmp/.X11-unix:ro \
		pika_ros_$(USER):latest bash

docker_exec:
	docker exec -it -w /pika_ws/src/pika_ros pika_ros_$(USER) bash
