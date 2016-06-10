#!/bin/bash -x
set -o nounset -o pipefail


## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installRiak.sh (presented with defaults)
                             (--nodename "riak@127.0.0.1") Nodename should be formatted with an ip or host?

  Install and configure Riak Node.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --nodename)           nodename="$2"                 ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function process {

    ## http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html

    device="/dev/xvdf"
    mount="/var/lib/riak"
    ## only try to attach/format the EBS if it is present.
    file -s "${device}" >> /dev/null
    isDeviceAttached=$?
    if [ ${isDeviceAttached} -eq 0 ]; then
        echo "we have our EBS volume attached at ${device}"
        ## check to ensure we have a filesystem on EBS
        hasFileSystem=$(file -s "${device}")
        if [ "${hasFileSystem}" == "${device}: data" ]; then
            echo "formatting device as it is not formatted. formatting.."
            mkfs -t ext4 "${device}"
        else
            echo "device is already formatted.."
        fi

        ## add mount to fstab
        grep -q /etc/fstab -e "${device}"
        alreadyInFstab=$?
        if [ ${alreadyInFstab} -eq 1 ]; then ## if 1 means no match - not in fstab
            echo "device not in fstab, adding..."
            cp /etc/fstab /etc/fstab.orig
            echo "${device}       ${mount}   ext4    defaults,nofail,nobootwait        0       2" | tee -a /etc/fstab
        else
            echo "device already in fstab, continuing..."
        fi

        ## now ensure its mounted at this moment.
        grep -qs "${mount}" /proc/mounts
        mountRet=$?
        if [ ${mountRet} -eq 0 ]; then
          echo "device already mounted, continuing...."
        else
          echo "device is not mounted, mounting now...."
          mkdir -p "${mount}"
          mount "${device}" "${mount}"
          if [ $? -eq 0 ]; then
           echo "Mount success!"
          else
           echo "Something went wrong with the mount!!!"
          fi
        fi
    else
        echo "we do not have our EBS volume attached at ${device}!"
    fi

    if [ -f /etc/riak/riak.conf ]; then
        echo "Riak already installed, skipping installation."
    else
        echo "Riak not installed, installing....."
        ## FIXME: we need to move this script to another location we can ensure we always have it or places with no network access.
        curl -s https://packagecloud.io/install/repositories/basho/riak/script.deb.sh | sudo bash
        apt-get install -y riak=2.1.1-1
    fi

    ## Update Riak Properties.
    ## FIXME: we should make these options configurable.
## Name of the Erlang node
##
## Default: riak@127.0.0.1
##
## Acceptable values:
##   - text
    sed -i'.bak' 's:^[ \t]*nodename[ \t]*=\([ \t]*.*\)$:nodename = '${nodename}':' /etc/riak/riak.conf
## Cookie for distributed node communication.  All nodes in the
## same cluster should use the same cookie or they will not be able to
## communicate.
##
## Default: riak
##
## Acceptable values:
##   - text
    sudo sed -i'.bak' 's:^[ \t]*distributed_cookie[ \t]*=\([ \t]*.*\)$:distributed_cookie = mthinx:' /etc/riak/riak.conf
## Number of concurrent node-to-node transfers allowed.
##
## Default: 2
##
## Acceptable values:
##   - an integer
##    sudo sed -i'.bak' 's:^[ \t]*transfer_limit[ \t]*=\([ \t]*.*\)$:transfer_limit = 2:' /etc/riak/riak.conf
##
## Default: /var/lib/riak
##
## Acceptable values:
##   - the path to a directory
    sudo sed -i'.bak' 's:^[ \t]*platform_data_dir[ \t]*=\([ \t]*.*\)$:platform_data_dir = /var/lib/riak:' /etc/riak/riak.conf
## Enable consensus subsystem. Set to 'on' to enable the
## consensus subsystem used for strongly consistent Riak operations.
##
## Default: off
##
## Acceptable values:
##   - on or off
##    sudo sed -i'.bak' 's:^[ \t]*strong_consistency[ \t]*=\([ \t]*.*\)$:strong_consistency = off:' /etc/riak/riak.conf
## listener.http.<name> is an IP address and TCP port that the Riak
## HTTP interface will bind.
##
## Default: 127.0.0.1:8098
##
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:10011
    sudo sed -i'.bak' 's|^[ \t]*listener.http.internal[ \t]*=\([ \t]*.*\)$|listener.http.internal = 0.0.0.0:8098|' /etc/riak/riak.conf
## listener.protobuf.<name> is an IP address and TCP port that the Riak
## Protocol Buffers interface will bind.
##
## Default: 127.0.0.1:8087
##
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:10011
    sudo sed -i'.bak' 's|^[ \t]*listener.protobuf.internal[ \t]*=\([ \t]*.*\)$|listener.protobuf.internal = 0.0.0.0:8087|' /etc/riak/riak.conf
## listener.https.<name> is an IP address and TCP port that the Riak
## HTTPS interface will bind.
##
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:10011
##    sudo sed -i'.bak' 's:^[ \t]*listener.https.internal[ \t]*=\([ \t]*.*\)$:listener.https.internal = 0.0.0.0:8099:' /etc/riak/riak.conf
## Specifies the storage engine used for Riak's key-value data
## and secondary indexes (if supported).
##
## Default: bitcask
##
## Acceptable values:
##   - one of: bitcask, leveldb, memory, multi, prefix_multi
    sudo sed -i'.bak' 's:^[ \t]*storage_backend[ \t]*=\([ \t]*.*\)$:storage_backend = bitcask:' /etc/riak/riak.conf
## A path under which bitcask data files will be stored.
##
## Default: $(platform_data_dir)/bitcask
##
## Acceptable values:
##   - the path to a directory
    sudo sed -i'.bak' 's:^[ \t]*bitcask.data_root[ \t]*=\([ \t]*.*\)$:bitcask.data_root = $(platform_data_dir)/bitcask:' /etc/riak/riak.conf
## Set to 'off' to disable the admin panel.
##
## Default: off
##
## Acceptable values:
##   - on or off
    sudo sed -i'.bak' 's:^[ \t]*riak_control[ \t]*=\([ \t]*.*\)$:riak_control = on:' /etc/riak/riak.conf
## Authentication mode used for access to the admin panel.
##
## Default: off
##
## Acceptable values:
##   - one of: off, userlist
##    sudo sed -i'.bak' 's:^[ \t]*riak_control.auth.mode[ \t]*=\([ \t]*.*\)$:riak_control.auth.mode = off:' /etc/riak/riak.conf
## If riak control's authentication mode (riak_control.auth.mode)
## is set to 'userlist' then this is the list of usernames and
## passwords for access to the admin panel.
## To create users with given names, add entries of the format:
## riak_control.auth.user.USERNAME.password = PASSWORD
## replacing USERNAME with the desired username and PASSWORD with the
## desired password for that user.
##
## Acceptable values:
##   - text
## riak_control.auth.user.admin.password = pass
##    sudo sed -i'.bak' 's:^[ \t]*riak_control.auth.user.admin.password[ \t]*=\([ \t]*.*\)$:riak_control.auth.user.admin.password = pass:' /etc/riak/riak.conf
## To enable Search set this 'on'.
##
## Default: off
##
## Acceptable values:
##   - on or off
    sudo sed -i'.bak' 's:^[ \t]*search[ \t]*=\([ \t]*.*\)$:search = on:' /etc/riak/riak.conf


    sudo rm /etc/riak/riak.conf.bak

}

function validate {
    if [ -z ${nodename+x} ]; then
      echo "ERROR --> Must pass in a --nodename for proper functioning"
      exit 1
    fi
}

## function that gets called, so executes all defined logic.
function main {

    options "$@"
    validate
    process

}


if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
