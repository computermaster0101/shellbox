#!/bin/bash
##
## Installs NTP client and sets timezone to UTC.
##
## NOTE: this has been tested against Ubuntu 14.04 only, so far.
##
AREA_ZONE=Etc/UTC

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true

cp /usr/share/zoneinfo/${AREA_ZONE} /etc/localtime
echo "${AREA_ZONE}" > /etc/timezone
dpkg-reconfigure -f non-interactive tzdata
apt-get install ntp -y
