#!/bin/bash -x
##
## Install RabbitMQ.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installRabbitmq.sh     (--adminUsername "")? (required)
                              (--adminPassword "")? (required)
                              (--changeGuestPasswordTo "")? (required)

  Install RabbitMQ Server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --adminUsername)            adminUsername="$2"                ; shift ;;
      --adminPassword)            adminPassword="$2"                ; shift ;;
      --changeGuestPasswordTo)    changeGuestPasswordTo="$2"        ; shift ;;
      --*)                        err "No such option: $1"                  ;;
    esac
    shift
  done
}

function process {
    echo "Installing RabbitMQ... "

    echo "Adding rabbitmq to /etc/apt/sources.list.d";
    sudo sh -c "echo \"deb http://www.rabbitmq.com/debian/ testing main\" > /etc/apt/sources.list.d/rabbitmq.list";

    echo "Installing the certificate";
    cd /tmp
    wget http://www.rabbitmq.com/rabbitmq-signing-key-public.asc
    sudo apt-key add rabbitmq-signing-key-public.asc
    rm rabbitmq-signing-key-public.asc

    echo "Installing rabbitmq-server";
    sudo apt-get update -y;
    sudo apt-get install rabbitmq-server -y;

    echo "Reseting rabbitmq-server";
    sudo rabbitmqctl stop_app;
    sudo rabbitmqctl reset;
    sudo rabbitmqctl start_app;

    echo "Configuring Plugins..."
    echo "  enabling rabbitmq_management"
    sudo rabbitmq-plugins enable rabbitmq_management
    echo "  enabling rabbitmq_stomp"
    sudo rabbitmq-plugins enable rabbitmq_stomp

    echo "Reseting rabbitmq-server after configuration";
    sudo rabbitmqctl stop_app;
    sudo rabbitmqctl reset;
    sudo rabbitmqctl start_app;

    echo "Creating admin user"
    sudo rabbitmqctl add_user ${adminUsername} ${adminPassword}
    sudo rabbitmqctl set_permissions ${adminUsername} ".*" ".*" ".*"
    sudo rabbitmqctl set_user_tags ${adminUsername} administrator
    sudo rabbitmqctl change_password guest ${changeGuestPasswordTo}

    echo "Final Rabbit Restart"
    sudo service rabbitmq-server stop
    sudo service rabbitmq-server start
}

function validate {
    if [ -z ${adminUsername+x} ]; then
        echo "** We require --adminUsername! We do not provide defaults for this field. "
        exit 1
    fi
    if [ -z ${adminPassword+x} ]; then
        echo "** We require --adminPassword! We do not provide defaults for this field. "
        exit 1
    fi
    if [ -z ${changeGuestPasswordTo+x} ]; then
        echo "** We require --changeGuestPasswordTo! We do not provide defaults for this field. "
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
