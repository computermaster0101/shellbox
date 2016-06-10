#!/bin/bash -x
set -o nounset -o pipefail

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: loadKibanaDashboards.sh (presented with defaults)
                             (--elasticsearchServer "localhost")?
                             (--elasticsearchPort "9200")?

  Load Dashboards for Kibana.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --elasticsearchServer)         elasticsearchServer="$2"          ; shift ;;
      --elasticsearchPort)           elasticsearchPort="$2"            ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function validateopts {
    if [ -z ${elasticsearchServer+x} ]; then
        elasticsearchServer="localhost"
        echo "** Elasticsearch server not set, using default --> ${elasticsearchServer}"
    fi
    if [ -z ${elasticsearchPort+x} ]; then
        elasticsearchPort=9200
        echo "** Elasticsearch port not set, using default --> ${elasticsearchPort}"
    fi
}

function process {
    sudo apt-get install -y unzip
    home=/opt/dashboards
    mkdir -p ${home}/MyDashboards
    unzip ${CURRENT_DIR}/MyDashboards.zip -d ${home}/MyDashboards
    cd ${home}/MyDashboards/MyDashboards
    ./load.sh -url http://${elasticsearchServer}:${elasticsearchPort}
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