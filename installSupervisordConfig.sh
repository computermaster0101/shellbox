#!/bin/bash -x
set -o nounset -o pipefail
##
## Script to create the proper configuration for Supervisord services.
##

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1;
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Test to ensure we have supervisor - install it.
command -v supervisord >/dev/null 2>&1 || { echo "Supervisor is Required but is not installed.  Installing now."; sudo apt-get install -y supervisor; }

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
Usage: install-supervisord.sh --name "required" --toexecute "required" --serviceuser "required" (presented with defaults)
                                    (--name " ")?
                                    (--toexecute " ")?
                                    (--serviceuser " ")?
                                    (--startsecs "10")?
                                    (--directory "/path/to/base/dir/")? (optional)
USAGE
}; function --help { -h ;}

function options {
    while [[ ${1:+isset} ]]
    do
        case "$1" in
            --name)         name="$2"               ; shift ;;
            --toexecute)    toexecute="$2"          ; shift ;;
            --serviceuser)  serviceuser="$2"        ; shift ;;
            --startsecs)    startsecs="$2"          ; shift ;;
            --directory)    directory="$2"          ; shift ;;
            --*)            err "No such option: $1" ;;
        esac
        shift
    done
}

function validateopts {
    if [ -z ${name+x} ]; then
        echo "** --name is required. Exiting now."
        exit 1;
    fi
    if [ -z ${toexecute+x} ]; then
        echo "** --toexecute is required. Exiting now."
        exit 1;
    fi
    if [ -z ${serviceuser+x} ]; then
        echo "** --serviceuser is required. Exiting now."
        exit 1;
    fi
    if [ -z ${startsecs+x} ]; then
        startsecs="10"
        echo "** startsecs not set, using default --> ${startsecs}"
    fi
    if [ -z ${directory+x} ]; then
        directory="/opt/"
        echo "** directory not set, using default --> ${directory}"
    fi
}


function process {
    mkdir -p /etc/supervisor/conf.d/
    SUPERVISORD_CONFIG=/etc/supervisor/conf.d/${name}.conf
    touch ${SUPERVISORD_CONFIG}

cat <<FILE > ${SUPERVISORD_CONFIG}
[program:${name}]
command=${toexecute}
directory=${directory}
user=${serviceuser}
autostart=true
autorestart=true
startsecs=${startsecs}
startretries=3
minfds=65536
stdout_logfile=/var/log/${name}-stdout.log
stderr_logfile=/var/log/${name}-stderr.log
FILE

    supervisorctl reread # make configuration changes available
    supervisorctl update # make new configurations available, restart changed config services - except new ones
    supervisorctl start ${name} # start new service.
}


function main {
    options "$@"
    validateopts
    process
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
