#!/bin/bash -x
set -o nounset -o pipefail

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }

sleep 10

## check we have elasticsearch already installed.
hasElasticsearch=$(curl -XGET "http://localhost:9200")
check=$(echo "${hasElasticsearch}" | grep "\"tagline\" : \"You Know, for Search\"")
if [ "${check}x" == x ]; then
  echo "elasticsearch service not found!  must have elasticsearch installed, configured, and running!"
  exit 1
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installLogstashCmdExecutor.sh (presented with defaults)
                             (--version "2.1")?

  Install and configure Logstash command executor.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
      --URL)                URL="$2"             ; shift ;;
      --serverName)                serverName="$2"             ; shift ;;
      --interval)           interval="$2"             ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function validate {
    if [ -z ${version+x} ]; then
        version="2.1"
        echo "** version not set, using default --> ${version}"
    fi
    if [ -z ${URL+x} ]; then
        echo "** url not set but reqired"
        exit 1;
    fi
    if [ -z ${interval+x} ]; then
        echo "** interval not set but reqired"
        exit 1;
    fi
}

function process {

   ## set instance details
   home=/opt/logstash-cmdExecutor

cat <<EOF > ${home}/cmdExecutor_server.conf.new
input {
    exec {
        command => "curl -o /dev/null --silent --head --write-out '%{http_code}\n' -XGET ${URL}"
        interval => ${interval}
        add_field => {
            URL => "${URL}"
            server => "${serverName}"
            tags => "urlstat"
        }
    }
}



EOF

    tail -n +2 ${home}/cmdExecutor_server.conf.new

    /opt/logstash-cmdExecutor/bin/logstash --configtest -f /opt/logstash-cmdExecutor/cmdExecutor_server.conf.new

    mv cmdExecutor_server.conf cmdExecutor_server.conf.prev
    mv cmdExecutor_server.conf.new cmdExecutor_server.conf
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
