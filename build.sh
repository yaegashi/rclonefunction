#!/bin/bash

set -ex

go build -v handler.go

RCLONE_RELEASE_URL=https://api.github.com/repos/rclone/rclone/releases/latest
RCLONE_DOWNLOAD_URL=$(curl -s $RCLONE_RELEASE_URL | sed -r -n 's,.*"(https://.*linux-amd64.zip)".*,\1,p')
curl -sL $RCLONE_DOWNLOAD_URL -o rclone.zip
unzip rclone.zip -d rclone.dir
mv rclone.dir/rclone-*/rclone .
rm -rf rclone.zip rclone.dir

rm -f rclonefunction.zip
zip -r rclonefunction.zip host.json handler rclone QueueTrigger1 TimerTrigger1
