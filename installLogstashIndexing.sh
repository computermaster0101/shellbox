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
USAGE: installLogstashIndexing.sh (presented with defaults)
                             (--version "2.1")?

  Install and configure Logstash Indexer.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
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
}

function process {
    if [ ! -f /etc/apt/sources.list.d/elastic.co.list ]; then
        ## Update package list to include logstash
        wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        echo "deb http://packages.elastic.co/logstash/${version}/debian stable main" | sudo tee /etc/apt/sources.list.d/elastic.co.list
    fi

    if [ ! -f /etc/apt/sources.list.d/beats.list ]; then
        ## Update package list to include logstash beats
        wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee /etc/apt/sources.list.d/beats.list
    fi

    if [ ! -f /opt/logstash ]; then
        home=/opt/logstash
        ## Update the system and install the packages
        sudo apt-get update -y
        sudo apt-get install -y logstash filebeat topbeat
        ## provide some information to easily find the version we are on.
        touch ${home}/version.txt
        echo "version: ${version}" >> ${home}/version.txt
        ## Install plugins
        cd ${home}/bin
        ./plugin install logstash-input-beats
    fi

    if [ ! -f /opt/logstash-indexing ]; then
        ## set instance details
        home=/opt/logstash-indexing
        user=logstash-indexing
        ## create user
        useradd -m ${user}
        ## lock created user from remote logins
        passwd -l ${user}
        ## create working directory
        cp -r /opt/logstash ${home}
        ## ensure proper permissions
        chgrp -R ${user} ${home}
        chown -R ${user} ${home}
        chmod -R g+rwX ${home}
    fi

## Update configuration files
cat <<EOF > ${home}/indexing_server.conf
input {
    redis {
        data_type => "list"
        key => "logstash"
    }
}


output {

    if ("topbeat" in [tags]){
        elasticsearch{
            hosts => "localhost"
            index => "topbeat-%{+YYYY.MM.dd}"
        }
    } elseif ("filebeat" in [tags]){
        elasticsearch{
            hosts => "localhost"
            index => "filebeat-%{+YYYY.MM.dd}"
        }
    } else {
        elasticsearch{
            hosts => "localhost"
        }
    }

}
EOF

    ## Ensure ElasticSearch has the correct templates for our beats.
    curl -XPUT "http://localhost:9200/_template/topbeat" -d@/etc/topbeat/topbeat.template.json
    curl -XPUT "http://localhost:9200/_template/filebeat" -d@/etc/filebeat/filebeat.template.json

    ## install service
    sudo bash ${CURRENT_DIR}/installSupervisordConfig.sh --name "logstash-indexing" --toexecute "${home}/bin/logstash -f ${home}/indexing_server.conf" --serviceuser "${user}"

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
