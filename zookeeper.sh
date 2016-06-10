#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

apt-get -y install zookeeperd
echo 1 | sudo dd of=/var/lib/zookeeper/myid"
