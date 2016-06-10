#!/bin/bash -x
set -o nounset -o pipefail


function globals {
  export LC_ALL=en_US.UTF-8
}; globals

# Calls a function of the same name for each needed variable.
function global {
  for arg in "$@"
  do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
  done
}

function -h {
cat <<USAGE
USAGE: logrotate.sh (presented with defaults)
                    (--service "")?
                    (--fullyQualifiedLogFile "/var/log/\${service}/\${service}.log")?

  Configure logrotate.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --service)                        service="$2"                              ; shift ;;
      --fullyQualifiedLogFile)          fullyQualifiedLogFile="$2"                ; shift ;;
      --*)                              err "No such option: $1"                          ;;
    esac
    shift
  done
}

function process {

    sudo apt-get install -y logrotate

    if [ ! -f /etc/logrotate.d/${service} ]; then
        sudo touch /etc/logrotate.d/${service}
        sudo su <<HERE
cat <<EOF > /etc/logrotate.d/${service}
"${fullyQualifiedLogFile}" {
  daily
  size 5M
  rotate 5
  create 664 root root
  missingok
  notifempty
  compress
  copytruncate
}
EOF
HERE
    fi

}


function validate {
    if [ -z ${service+x} ]; then
        echo "** You must provide --service 'service' so we know what to configure. "
        exit 1
    fi
    if [ -z ${fullyQualifiedLogFile+x} ]; then
        fullyQualifiedLogFile="/var/log/${service}/${service}.log"
        echo "** fullyQualifiedLogFile not set, using default --> ${fullyQualifiedLogFile}"
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
