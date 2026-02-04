SHELL := /bin/bash
BASE := $(shell pwd)
DOCKER_USER_UID := $(shell id -u)

docker_build:
	docker build -t pika_ros_$(USER):latest .

docker_run:
	mkdir -p $(HOME)/.docker_bash_history_pika && \
	docker run -it --rm --network=host --privileged \
		--name pika_ros_$(USER) \
		--ipc=host \
		-v $(BASE)/src:/root/pika_ros/src \
		-v $(BASE)/scripts:/root/pika_ros/scripts \
		-v $(HOME)/.docker_bash_history_pika:/root/.bash_history \
		-w /root/pika_ros \
		-e DISPLAY=$(DISPLAY) \
		-e DOCKER_USER_UID=$(DOCKER_USER_UID) \
		-e QT_X11_NO_MITSHM=1 \
		-v /tmp/.X11-unix:/tmp/.X11-unix:ro \
		pika_ros_$(USER):latest bash

docker_exec:
	docker exec -it -w /root/pika_ros pika_ros_$(USER) bash
