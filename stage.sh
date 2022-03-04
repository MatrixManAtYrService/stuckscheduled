#! /usr/bin/env bash
set -x
docker build . -f Dockerfile_422 -t stuck422:latest
docker tag stuck422:latest localhost:5000/stuck422:latest
docker push localhost:5000/stuck422:latest

docker build . -f Dockerfile_main -t stuckmain:latest
docker tag stuckmain:latest localhost:5000/stuckmain:latest
docker push localhost:5000/stuckmain:latest
