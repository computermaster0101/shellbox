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
USAGE: installKibana.sh (presented with defaults)
                             (--version "4.3.0")?
                             (--serverPort "8081")?
                             (--serverHost "0.0.0.0")?
                             (--esURL "http://localhost:9200")?
  Install and configure Kibana.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
      --serverPort)         serverPort="$2"          ; shift ;;
      --serverHost)         serverHost="$2"          ; shift ;;
      --esURL)              esURL="$2"               ; shift ;;
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
    if [ -z ${serverPort+x} ]; then
        serverPort=8081
        echo "** serverPort not set, using default --> ${serverPort}"
    fi
    if [ -z ${serverHost+x} ]; then
        serverHost="0.0.0.0"
        echo "** serverHost not set, using default --> ${serverHost}"
    fi
    if [ -z ${esURL+x} ]; then
        esURL="http://localhost:9200"
        echo "** esURL not set, using default --> ${esURL}"
    fi
}

function process {
    home=/opt/kibana
    user=kibana

    pkg_url=https://download.elastic.co/kibana/kibana
    pkg=kibana-${version}-linux-x64

    if [ ! -f ${home}/${pkg} ]; then
        ## make a logstash user
        useradd -m ${user}
        ## lock the logstash user from remote logins
        passwd -l ${user}
        ## create working directory
        mkdir -p ${home}

        ## Update package list to include logstash
        cd ${home}
        curl -O ${pkg_url}/${pkg}.tar.gz

        ## Update the system and install the packages
        tar -xf ${pkg}.tar.gz
    fi
        ## need to get some configuration files, we can either do them inline. Any element in the configuration can be
        ## replaced with environment variables by placing them in ${...} notation.
        ## For example: myElement=${myElement}
        ## myElement can then me given a default and overwritten using options passed in.

        ## add templates

cat <<EOF > ${home}/${pkg}/config/kibana.yml
server.port: ${serverPort}
server.host: ${serverHost}
elasticsearch.url: ${esURL}
EOF

    ## provide some information to easily find the version we are on.
    touch ${home}/version.txt
    echo "kibana-version: ${version}" >> ${home}/version.txt

    ## ensure proper permissions
    chgrp -R ${user} ${home}
    chown -R ${user} ${home}
    chmod -R g+rwX ${home}

    ## install service
    ${CURRENT_DIR}/installSupervisordConfig.sh --name "kibana" --toexecute "${home}/${pkg}/bin/kibana" --serviceuser "${user}"

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