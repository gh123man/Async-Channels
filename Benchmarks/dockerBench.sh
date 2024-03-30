#!/bin/bash 

set -e

cd ..
docker build -f Benchmarks/Dockerfile -t swift-async-channles-bench .
echo "Running benchmarks!"
docker run -it swift-async-channles-bench