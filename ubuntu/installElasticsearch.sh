#!/bin/bash -x
set -o nounset -o pipefail

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installElasticsearch.sh (presented with defaults)
                             (--version "1.3.2")?
                             (--jvmArgs "-server -Xmx2048M -Xms2048M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts ")?
                             (--clusterName "logMonitoring")?
                             (--discoveryType "ec2")?
                             (--installCurator true)?
                             (--mlockall false)?
                             (--esLoggerLevel "debug")?
                             (--networkHost "0.0.0.0")?
                             (--httpPort 9200)?
                             (--dataDir "/usr/share/elasticsearch")?
                             
  Install and configure Elastic Search.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
      --jvmArgs)            jvmArgs="$2"             ; shift ;;
      --clusterName)        clusterName="$2"         ; shift ;;
      --discoveryType)      discoveryType="$2"       ; shift ;;
      --installCurator)     installCurator="$2"      ; shift ;;
      --mlockall)           mlockall="$2"            ; shift ;;
      --esLoggerLevel)      esLoggerLevel="$2"       ; shift ;;
      --clusterName)        clusterName="$2"         ; shift ;;
      --networkHost)        networkHost="$2"         ; shift ;;
      --httpPort)           httpPort="$2"            ; shift ;;
      --dataDir)           dataDir="$2"            ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function validateopts {
    if [ -z ${version+x} ]; then
        version="1.3.2"
        echo "** version not set, using default --> ${version}"
    fi
    if [ -z ${jvmArgs+x} ]; then
        jvmArgs="-server -Xmx2048M -Xms2048M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts "
        echo "** jvmArgs not set, using default --> ${jvmArgs}"
    fi
    if [ -z ${clusterName+x} ]; then
        clusterName="logMonitoring"
        echo "** clusterName not set, using default --> ${clusterName}"
    fi
    if [ -z ${discoveryType+x} ]; then
        discoveryType="ec2"
        echo "** discoveryType not set, using default --> ${discoveryType}"
    fi
    if [ -z ${installCurator+x} ]; then
        installCurator=false
        echo "** installCurator not set, using default --> ${installCurator}"
    fi
    if [ -z ${mlockall+x} ]; then
        mlockall="false"
        echo "** mlockall not set, using default --> ${mlockall}"
    fi
    if [ -z ${esLoggerLevel+x} ]; then
        esLoggerLevel="debug"
        echo "** esLoggerLevel not set, using default --> ${esLoggerLevel}"
    fi

    if [ -z ${networkHost+x} ]; then
        networkHost="0.0.0.0"
        echo "** networkHost not set, using default --> ${networkHost}"
    fi
    if [ -z ${httpPort+x} ]; then
        httpPort=9200
        echo "** httpPort not set, using default --> ${httpPort}"
    fi
    if [ -z ${dataDir+x} ]; then
        dataDir="/usr/share/elasticsearch"
        echo "** dataDir not set, using default --> ${dataDir}"
    fi

}

function process {
    home=/usr/share/elasticsearch
    user=elastic

    if [ ! -f /etc/apt/sources.list.d/elasticsearch-2.x.list ]; then
        ## Update package list to include elasticsearch and logstash
        wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
    fi

    if [ ! -f /usr/share/elasticsearch/bin/elasticsearch ]; then

        ## make a tomcat8 user
        useradd -m ${user}
        ## lock the tomcat8 user from remote logins
        passwd -l ${user}
        ## create working directory
        mkdir -p ${home}

        ## Update the system and install the packages
        sudo apt-get update
        sudo apt-get install elasticsearch

        ## install plugins
        cd ${home}
        mkdir -p config/templates
        ${home}/bin/plugin install royrusso/elasticsearch-HQ
        ${home}/bin/plugin install elasticsearch/elasticsearch-cloud-aws/2.3.0
    fi

    ## create configuration files
cat <<'EOF' > ${home}/config/logging.yml
# you can override this using by setting a system property, for example -Des.logger.level=DEBUG
es.logger.level: INFO
rootLogger: ${es.logger.level}, console, file
logger:
  # log action execution errors for easier debugging
  action: DEBUG

  # deprecation logging, turn to DEBUG to see them
  deprecation: INFO, deprecation_log_file

  # reduce the logging for aws, too much is logged under the default INFO
  com.amazonaws: WARN
  # aws will try to do some sketchy JMX stuff, but its not needed.
  com.amazonaws.jmx.SdkMBeanRegistrySupport: ERROR
  com.amazonaws.metrics.AwsSdkMetrics: ERROR

  org.apache.http: INFO

  # gateway
  #gateway: DEBUG
  #index.gateway: DEBUG

  # peer shard recovery
  #indices.recovery: DEBUG

  # discovery
  #discovery: TRACE

  index.search.slowlog: TRACE, index_search_slow_log_file
  index.indexing.slowlog: TRACE, index_indexing_slow_log_file

additivity:
  index.search.slowlog: false
  index.indexing.slowlog: false
  deprecation: false

appender:
  console:
    type: console
    layout:
      type: consolePattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"

  file:
    type: dailyRollingFile
    file: ${path.logs}/${cluster.name}.log
    datePattern: "'.'yyyy-MM-dd"
    layout:
      type: pattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %.10000m%n"

  # Use the following log4j-extras RollingFileAppender to enable gzip compression of log files.
  # For more information see https://logging.apache.org/log4j/extras/apidocs/org/apache/log4j/rolling/RollingFileAppender.html
  #file:
    #type: extrasRollingFile
    #file: ${path.logs}/${cluster.name}.log
    #rollingPolicy: timeBased
    #rollingPolicy.FileNamePattern: ${path.logs}/${cluster.name}.log.%d{yyyy-MM-dd}.gz
    #layout:
      #type: pattern
      #conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"

  deprecation_log_file:
    type: dailyRollingFile
    file: ${path.logs}/${cluster.name}_deprecation.log
    datePattern: "'.'yyyy-MM-dd"
    layout:
      type: pattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"

  index_search_slow_log_file:
    type: dailyRollingFile
    file: ${path.logs}/${cluster.name}_index_search_slowlog.log
    datePattern: "'.'yyyy-MM-dd"
    layout:
      type: pattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"

  index_indexing_slow_log_file:
    type: dailyRollingFile
    file: ${path.logs}/${cluster.name}_index_indexing_slowlog.log
    datePattern: "'.'yyyy-MM-dd"
    layout:
      type: pattern
      conversionPattern: "[%d{ISO8601}][%-5p][%-25c] %m%n"
EOF

cat <<EOF > ${home}/config/elasticsearch.yml
# ======================== Elasticsearch Configuration =========================
#
# NOTE: Elasticsearch comes with reasonable defaults for most settings.
#       Before you set out to tweak and tune the configuration, make sure you
#       understand what are you trying to accomplish and the consequences.
#
# The primary way of configuring a node is via this file. This template lists
# the most important settings you may want to configure for a production cluster.
#
# Please see the documentation for further information on configuration options:
# <http://www.elastic.co/guide/en/elasticsearch/reference/current/setup-configuration.html>
#
# ---------------------------------- Cluster -----------------------------------
#
# Use a descriptive name for your cluster:
#
cluster.name: ${clusterName}
#
# ------------------------------------ Node ------------------------------------
#
# Use a descriptive name for the node:
#
# node.name: node-1
#
# Add custom attributes to the node:
#
# node.rack: r1
#
# ----------------------------------- Paths ------------------------------------
#
# Path to directory where to store the data (separate multiple locations by comma):
#
path.data: ${dataDir}/data
#
# Path to log files:
#
path.logs: /var/log/elasticsearch
#
# ----------------------------------- Memory -----------------------------------
#
# Lock the memory on startup:
#
bootstrap.mlockall: ${mlockall}
#
# Make sure that the ES_HEAP_SIZE environment variable is set to about half the memory
# available on the system and that the owner of the process is allowed to use this limit.
#
# Elasticsearch performs poorly when the system is swapping the memory.
#
# ---------------------------------- Network -----------------------------------
#
# Set the bind address to a specific IP (IPv4 or IPv6):
#
network.host: ${networkHost}
#
# Set a custom port for HTTP:
#
http.port: ${httpPort}
#
# For more information, see the documentation at:
# <http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html>
#
# ---------------------------------- Gateway -----------------------------------
#
# Block initial recovery after a full cluster restart until N nodes are started:
#
# gateway.recover_after_nodes: 3
#
# For more information, see the documentation at:
# <http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-gateway.html>
#
# --------------------------------- Discovery ----------------------------------
#
# Elasticsearch nodes will find each other via unicast, by default.
#
# Pass an initial list of hosts to perform discovery when new node is started:
# The default list of hosts is ["127.0.0.1", "[::1]"]
#
# discovery.zen.ping.unicast.hosts: ["host1", "host2"]
#
# Prevent the "split brain" by configuring the majority of nodes (total number of nodes / 2 + 1):
#
# discovery.zen.minimum_master_nodes: 3
#
# For more information, see the documentation at:
# <http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html>
#
# ---------------------------------- Various -----------------------------------
#
# Disable starting multiple nodes on a single system:
#
# node.max_local_storage_nodes: 1
#
# Require explicit names when deleting indices:
#
# action.destructive_requires_name: true
EOF


cat <<EOF > ${home}/config/templates/eventdata.json
{
    "template" : "eventdata-*",
    "settings" : {
        "index.number_of_shards" : 1,
        "index.number_of_replicas" : 1,
        "index.refresh_interval" : "5s"
    },
    "aliases" : {
        "eventdata_historical" : {}
    }
}
EOF

cat <<EOF > ${home}/config/templates/eventstreamdefinition.json
{
    "template" : "event-stream-definition",
    "settings" : {
        "index.number_of_shards" : 6,
        "index.number_of_replicas" : 1,
        "index.refresh_interval" : "5s"
    },
    "aliases" : {
        "event_stream_definition" : {}
    }
}
EOF



if [ ${installCurator} == true ]; then

    ## add curator cron job
cat <<'EOF' > ${home}/curator-cron.sh
#!/bin/sh
#
# Perform nightly elasticsearch tasks.
#

# we will ensure all our deps are installed and ready to go.

# ensure we have pip installed - python package manager
if command -v pip >/dev/null; then
    echo "pip installed and ready to use."
  else
    echo "pip not installed, installing..."
    sudo apt-get -y install python-pip;
fi

# ensure we have curator installed.
if command -v curator >/dev/null; then
    echo "curator installed and ready to use."
  else
    echo "curator not installed, installing..."
    sudo pip install elasticsearch-curator;
fi

# ensure ntp is installed and ready to go
if command -v ntpd >/dev/null; then
        echo "ntp installed and ready to use."
    else
        echo "ntp not installed, intalling..."
        sudo apt-get -y install ntp
        # update ntp.conf after since it is created on ntp install
        sudo sh -c "echo 'server 0.pool.ntp.org \nserver 1.pool.ntp.org \nserver 2.pool.ntp.org \nserver 3.pool.ntp.org' > /etc/ntp.conf"
        sudo service ntp restart
        echo "ntp installed and configured."
fi


# add new index to the system.
TODAY=$(date +"%m-%d-%Y")
YESTERDAY=$(date --date="yesterday" +"%m-%d-%Y")
TODAYS_INDEX="eventdata-${TODAY}"
YESTERDAYS_INDEX="eventdata-${YESTERDAY}"

echo "TODAY : ${TODAY}"
echo "YESTERDAY : ${YESTERDAY}"
echo "TODAYS_INDEX : ${TODAYS_INDEX}"
echo "YESTERDAYS_INDEX : ${YESTERDAYS_INDEX}"

response=$(curl --write-out %{http_code} --silent --output /dev/null -XHEAD "http://127.0.0.1:9200/${TODAYS_INDEX}")
echo "Index exists (404 not) (200 exists) : ${response}"
if [ "${response}" -eq "404" ]; then
        echo "we dont have the index, so create it and add alias"

        curl -XPUT "http://127.0.0.1:9200/${TODAYS_INDEX}"
        # remove old index from alias and add new index
        request="{ "actions" : [ { "remove" : { "index" : "${YESTERDAYS_INDEX}", "alias" : "eventdata_current" } }, { "add" : { "index" : "${TODAYS_INDEX}", "alias" : "eventdata_current" } } ] }"
        echo "${request}"
        curl -XPOST "http://127.0.0.1:9200/_aliases" -d "${request}"
    else
        echo "index for today already created and alias should already be added."
fi
EOF

    chmod +x ${home}/curator-cron.sh
    command="${home}/curator-cron.sh"
    cron="00 00 * * * ${command}"
    ( crontab -l | grep -v "${command}" ; echo "${cron}" ) | crontab -
fi

    ## provide some information to easily find the version we are on.
    touch ${home}/version.txt
    echo "es-version: ${version}" >> ${home}/version.txt

    ## ensure proper permissions
    chgrp -R ${user} ${home}
    chown -R ${user} ${home}
    chmod -R g+rwX ${home}

    ## ensure we have the ES_JAVA_OPTS env variable set
    echo "export ES_JAVA_OPTS=\"${jvmArgs}\"" >> /etc/environment
    source /etc/environment

    ## install service
    ${CURRENT_DIR}/installSupervisordConfig.sh --name "elasticsearch" --toexecute "${home}/bin/elasticsearch" --serviceuser "${user}"

#    reboot
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
