#! /usr/bin/env bash
set -x
docker build . -t stuckscheduled:latest
docker tag stuckscheduled:latest localhost:5000/stuckscheduled:latest
docker push localhost:5000/stuckscheduled:latest
