#!/bin/bash

docker build --progress=plain --build-arg MINECRAFT_VERSION=1.19.2 -t mctest:1.19.2 .
