#!/bin/bash -x
set -o nounset -o pipefail

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installRedis.sh (presented with defaults)
                             (--version "4.3.0")?
                             (--ulimitNumber 65536)?

  Install and configure Redis.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
      --port)               port="$2"                ; shift ;;
      --loglevel)           loglevel="$2"            ; shift ;;
      --bind)               bind="$2"                ; shift ;;
      --datadir)            datadir="$2"             ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function validateopts {

    if [ -z ${version+x} ]; then
        version="4.3.0"
        echo "** version not set, using default --> ${version}"
    fi

    if [ -z ${port+x} ]; then
        port=6379
        echo "**port not set, using default --> ${port}"
    fi

    if [ -z ${loglevel+x} ]; then
        loglevel="notice"
        echo "**port not set, using default --> ${loglevel}"
    fi

    if [ -z ${bind+x} ]; then
        bind="0.0.0.0"
        echo "**port not set, using default --> ${bind}"
    fi

    if [ -z ${datadir+x} ]; then
        datadir="/var/lib/redis"
        echo "**port not set, using default --> ${datadir}"
    fi
}

function process {
    redis_home=/opt/redis
    user=redis

    pkg_url=http://download.redis.io
    pkg=redis-stable

    apt-get install -y make
    apt-get install -y gcc

    ## make a logstash user
    useradd -m ${user}
    ## lock the logstash user from remote logins
    passwd -l ${user}
    ## create working directory
    mkdir -p ${redis_home}

    ## Update package list to include logstash
    cd ${redis_home}
    curl -O ${pkg_url}/${pkg}.tar.gz

    ## Update the system and install the packages
    tar -xf ${pkg}.tar.gz
    cd ${pkg}
    make

    ## need to get some configuration files, we can either do them inline. Any element in the configuration can be
    ## replaced with environment variables by placing them in ${...} notation.
    ## For example: myElement=${myElement}
    ## myElement can then me given a default and overwritten using options passed in.

cat <<EOF > ${redis_home}/redis.conf
port ${port}
bind ${bind}
loglevel ${loglevel}
dir ${redis_home}

daemonize no
pidfile ${redis_home}/redis.pid
logfile ${redis_home}/redis.log
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename redis.rdb
EOF


    ## provide some information to easily find the version we are on.
    touch ${redis_home}/version.txt
    echo "redis-version: ${version}" >> ${redis_home}/version.txt

    ## ensure proper permissions
    chown -R ${user}:${user} ${redis_home}
    chmod -R 770 ${redis_home}

    ## install service
    ${CURRENT_DIR}/installSupervisordConfig.sh --name "redis" --toexecute "${redis_home}/${pkg}/src/redis-server ${redis_home}/redis.conf" --serviceuser "root"
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