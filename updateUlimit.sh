#!/bin/bash -x
set -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: updateUlimit.sh (presented with defaults)
                       (--openFileLimit 65536)?

  Configure ulimit on ubuntu, must reboot server after running.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --openFileLimit)                  openFileLimit="$2"                        ; shift ;;
      --*)                              err "No such option: $1"                          ;;
    esac
    shift
  done
}

function process {

    ## ensure we increase the FD limit.
    sudo su <<HERE
cat <<EOF >> /etc/security/limits.conf
* soft nproc ${openFileLimit}

* hard nproc  ${openFileLimit}

* soft nofile  ${openFileLimit}

* hard nofile  ${openFileLimit}
EOF
HERE

    sudo su <<HERE
echo "fs.file-max = ${openFileLimit}" >> /etc/sysctl.conf
HERE


}


function validate {
    if [ -z ${openFileLimit+x} ]; then
        openFileLimit=65536
        echo "** openFileLimit not set, using default --> ${openFileLimit}"
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
