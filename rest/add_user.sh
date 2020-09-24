#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage: $0 <USERNAME> <PASSWORD>"
  exit 1
fi

docker exec graphsense-rest flask create-user "$1" "$2"
