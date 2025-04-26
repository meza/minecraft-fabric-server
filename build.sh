#!/bin/bash

docker build --no-cache --progress=plain --build-arg MINECRAFT_VERSION=25w14craftmine -t vsbmeza/mctest:25w14craftmine .
