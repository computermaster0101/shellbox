#!/bin/bash -x
##
## Add HaProxy Server.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: addHaProxyServer.sh    (--privateDNS "")?(required)
                              (--privateIP "")?(required)
                              (--port "8080")?(optional)

  Add HaProxy Server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --privateDNS)               privateDNS="$2"                   ; shift ;;
      --privateIP)                privateIP="$2"                    ; shift ;;
      --port)                     port="$2"                         ; shift ;;
      --*)                        err "No such option: $1"                  ;;
    esac
    shift
  done
}

function process {
    echo "Add HaProxy Server... "

    ## if we have a match already in file
    if [ $(grep -q "server ${privateDNS}" /etc/haproxy/haproxy.cfg) ]; then
        echo "server dns is in haproxy config file already, checking if update is required..."
        updateServer=false
        # we should now check for private ip and port to ensure our configuration for this guys is correct.
        if [ $(grep -q "server ${privateDNS} ${privateIP}" /etc/haproxy/haproxy.cfg) ]; then
            echo "server ip is already in haproxy config file, checking port..."
            grep -q /etc/haproxy/haproxy.cfg -e "server ${privateDNS} ${privateIP}:${port}"
            havePortAlready=$?
            if [ $(grep -q "server ${privateDNS} ${privateIP}:${port}" /etc/haproxy/haproxy.cfg) ]; then
                echo "server port is already in haproxy config file, no updates needed."
            else
                updateServer=true
            fi
        else
            updateServer=true
        fi

        ## now update if needed, we replace the whole line with updated information
        if [ "${updateServer}" == "true" ]; then
            echo "server dns is being updated.."
            adjustedDns=$(echo "${privateDNS}" | sed -e 's:\.:\\.:g')
            sudo sed -i'.bak' "s|[ \t]server ${adjustedDns}.*|server ${privateDNS} ${privateIP}:${port} weight 1 maxconn 20000 check|" /etc/haproxy/haproxy.cfg
        else
            echo "server dns is in haproxy and up to date, not changes needed."
        fi
    else
        echo "server dns is not in haproxy config file, adding..."
        cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
        echo -e "\tserver ${privateDNS} ${privateIP}:${port} weight 1 maxconn 20000 check" | sudo tee -a /etc/haproxy/haproxy.cfg
    fi

    sudo service haproxy restart
    echo "Done adding/updating haproxy."
}

function validate {
    if [ -z ${privateDNS+x} ]; then
        echo "** You must provide --privateDNS '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${privateIP+x} ]; then
        echo "** You must provide --privateIP '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${port+x} ]; then
        port="8080"
        echo "** port not set, using default --> ${port}"
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

