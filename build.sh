#!/bin/bash

set -ex

go build -v handler.go
GOBIN=$PWD go install -v github.com/rclone/rclone@latest
