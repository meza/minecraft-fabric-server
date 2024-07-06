#!/bin/bash

docker build --no-cache --progress=plain --build-arg MINECRAFT_VERSION=1.21 -t mctest:1.21 .
