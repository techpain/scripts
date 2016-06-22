#!/bin/bash


## This script is designed to help me cleanup my docker fluff


########## REMOVE OLD CONTAINERS
if [ "$1" = "--containers" ]; then

	docker ps -a | grep 'weeks ago' | awk '{print $1}' | xargs --no-run-if-empty docker rm
fi

########## REMOVE UNTAGGED IMAGES
if [ "$1" = "--images" ]; then

	docker rmi $(docker images | grep "^<none>" | awk '{print $3}')
fi
