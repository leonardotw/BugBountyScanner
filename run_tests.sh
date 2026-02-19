#!/bin/bash
# script to run tests inside the Docker container

IMAGE_NAME="bugbountyscanner"

# Check if image exists
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
  echo "[-] Image $IMAGE_NAME not found. Please build it first:"
  echo "    docker build -t $IMAGE_NAME ."
  exit 1
fi

echo "[*] Running tests inside container..."
docker run --rm $IMAGE_NAME bats /root/tests/test_basic.bats
