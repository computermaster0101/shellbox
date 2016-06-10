#!/bin/bash -x
##
## Setup RabbitMQ Slave Node.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installRabbitmq.sh     (--adminUsername "")? (required)
                              (--masterHostname "")? (required)

  Install RabbitMQ Server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --adminUsername)            adminUsername="$2"                ; shift ;;
      --masterHostname)           masterHostname="$2"               ; shift ;;
      --*)                        err "No such option: $1"                  ;;
    esac
    shift
  done
}

function process {
    echo "Setting up slave node"

    # Will Setup a rabbitmq slave you need to have then $MASTER_HOSTNAME set
    sudo rabbitmqctl stop_app;
    sudo rabbitmqctl reset;
    sudo rabbitmqctl join_cluster --ram ${adminUsername}@${masterHostname};
    sudo rabbitmqctl start_app;
    sudo rabbitmqctl cluster_status;

    echo "Rabbitmq Slave node setup"
}

function validate {
    if [ -z ${adminUsername+x} ]; then
        echo "** We require --adminUsername! We do not provide defaults for this field. "
        exit 1
    fi
    if [ -z ${masterHostname+x} ]; then
        echo "** We require --masterHostname! We do not provide defaults for this field. "
        exit 1
    fi
}

function main {
  options "$@"
  validate
  process
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi

