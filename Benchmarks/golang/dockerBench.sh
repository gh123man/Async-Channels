#!/bin/bash 
set -e
docker build -t golang-channel-bench .

docker run -it golang-channel-bench