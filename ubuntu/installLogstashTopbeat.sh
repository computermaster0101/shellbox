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
USAGE: installLogstashTopbeat.sh (presented with defaults)
                             (--version "2.1")?
                             (--logstashServer "localhost")?
                             (--logstashPort 9210)?
                             (--tag "")?
                             (--serverName "")?

  Install and configure Logstash Topbeat.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)            version="$2"             ; shift ;;
      --logstashServer)     logstashServer="$2"      ; shift ;;
      --logstashPort)       logstashPort="$2"        ; shift ;;
      --tag)                tag="$2"                 ; shift ;;
      --serverName)         serverName="$2"                 ; shift ;;
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
    if [ -z ${logstashServer+x} ]; then
        logstashServer="localhost"
        echo "** Logstash address not set, using default --> ${logstashServer}"
    fi
    if [ -z ${logstashPort+x} ]; then
        logstashPort="9210"
        echo "** Elasticsearch address not set, using default --> ${logstashPort}"
    fi
    if [ -z ${serverName+x} ]; then
        echo "** serverName not set but is required. Exiting now."
        exit 1
    fi

}

function process {
    if [ ! -f /etc/apt/sources.list.d/beats.list ]; then
        ## Update package list to include logstash beats
        wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee /etc/apt/sources.list.d/beats.list
    fi

    if [ ! -f /etc/topbeat ]; then
        ## set instance details
        home=/etc/topbeat
        user=topbeat
        ## create user
        useradd -m ${user}
        ## lock created user from remote logins
        passwd -l ${user}
        ## create working directory
        cp -r /opt/logstash ${home}
        ## Update the system and install the packages
        sudo apt-get update -y
        sudo apt-get install -y topbeat
        ## provide some information to easily find the version we are on.
        touch ${home}/version.txt
        echo "version: ${version}" >> ${home}/version.txt
    fi

## Update configuration files
## WARNING: formatting/indenting is specific and mustn't be changed.
cat <<'EOF' > ${home}/topbeat.yml
################### Topbeat Configuration Example #########################

############################# Input ############################################
input:
  # In seconds, defines how often to read server statistics
  period: 300

  # Regular expression to match the processes that are monitored
  # By default, all the processes are monitored
  procs: [".*"]

  # Statistics to collect (all enabled by default)
  stats:
    system: true
    proc: true
    filesystem: true
###############################################################################
############################# Libbeat Config ##################################
# Base config file used by all other beats for using libbeat features

############################# Output ##########################################

# Configure what outputs to use when sending the data collected by the beat.
# Multiple outputs may be used.
output:

  ### Elasticsearch as output
  # elasticsearch:
    # Array of hosts to connect to.
    # Scheme and port can be left out and will be set to the default (http and 9200)
    # In case you specify and additional path, the scheme is required: http://localhost:9200/path
    # IPv6 addresses should always be defined as: https://[2001:db8::1]:9200
    # hosts: ["${lsAddress}"]

    # Optional protocol and basic auth credentials. These are deprecated.
    #protocol: "https"
    #username: "admin"
    #password: "s3cr3t"

    # Number of workers per Elasticsearch host.
    # worker: 1

    # Optional index name. The default is "topbeat" and generates
    # [topbeat-]YYYY.MM.DD keys.
    #index: "topbeat"

    # Optional HTTP Path
    #path: "/elasticsearch"

    # The number of times a particular Elasticsearch index operation is attempted. If
    # the indexing operation doesn't succeed after this many retries, the events are
    # dropped. The default is 3.
    #max_retries: 3

    # The maximum number of events to bulk in a single Elasticsearch bulk API index request.
    # The default is 50.
    #bulk_max_size: 50

    # Configure http request timeout before failing an request to Elasticsearch.
    #timeout: 90

    # The number of seconds to wait for new events between two bulk API index requests.
    # If `bulk_max_size` is reached before this interval expires, addition bulk index
    # requests are made.
    #flush_interval: 1

    # Boolean that sets if the topology is kept in Elasticsearch. The default is
    # false. This option makes sense only for Packetbeat.
    #save_topology: false

    # The time to live in seconds for the topology information that is stored in
    # Elasticsearch. The default is 15 seconds.
    #topology_expire: 15

    # tls configuration. By default is off.
    #tls:
      # List of root certificates for HTTPS server verifications
      #certificate_authorities: ["/etc/pki/root/ca.pem"]

      # Certificate for TLS client authentication
      #certificate: "/etc/pki/client/cert.pem"

      # Client Certificate Key
      #certificate_key: "/etc/pki/client/cert.key"

      # Controls whether the client verifies server certificates and host name.
      # If insecure is set to true, all server host names and certificates will be
      # accepted. In this mode TLS based connections are susceptible to
      # man-in-the-middle attacks. Use only for testing.
      #insecure: true

      # Configure cipher suites to be used for TLS connections
      #cipher_suites: []

      # Configure curve types for ECDHE based cipher suites
      #curve_types: []

      # Configure minimum TLS version allowed for connection to logstash
      #min_version: 1.0

      # Configure maximum TLS version allowed for connection to logstash
      #max_version: 1.2
EOF
cat <<EOF >> ${home}/topbeat.yml

  ### Logstash as output
  logstash:
    # The Logstash hosts
    hosts: ["${logstashServer}:${logstashPort}"]
EOF
cat <<'EOF' >> ${home}/topbeat.yml
    # Number of workers per Logstash host.
    #worker: 1

    # Optional load balance the events between the Logstash hosts
    #loadbalance: true

    # Optional index name. The default index name depends on the each beat.
    # For Packetbeat, the default is set to packetbeat, for Topbeat
    # top topbeat and for Filebeat to filebeat.
    #index: topbeat

    # Optional TLS. By default is off.
    #tls:
      # List of root certificates for HTTPS server verifications
      #certificate_authorities: ["/etc/pki/root/ca.pem"]

      # Certificate for TLS client authentication
      #certificate: "/etc/pki/client/cert.pem"

      # Client Certificate Key
      #certificate_key: "/etc/pki/client/cert.key"

      # Controls whether the client verifies server certificates and host name.
      # If insecure is set to true, all server host names and certificates will be
      # accepted. In this mode TLS based connections are susceptible to
      # man-in-the-middle attacks. Use only for testing.
      #insecure: true

      # Configure cipher suites to be used for TLS connections
      #cipher_suites: []

      # Configure curve types for ECDHE based cipher suites
      #curve_types: []


  ### File as output
  #file:
    # Path to the directory where to save the generated files. The option is mandatory.
    #path: "/tmp/topbeat"

    # Name of the generated files. The default is `topbeat` and it generates files: `topbeat`, `topbeat.1`, `topbeat.2`, etc.
    #filename: topbeat

    # Maximum size in kilobytes of each file. When this size is reached, the files are
    # rotated. The default value is 10 MB.
    #rotate_every_kb: 10000

    # Maximum number of files under path. When this number of files is reached, the
    # oldest file is deleted and the rest are shifted from last to first. The default
    # is 7 files.
    #number_of_files: 7


  ### Console output
  # console:
    # Pretty print json event
    #pretty: false


############################# Shipper #########################################

shipper:
  # The name of the shipper that publishes the network data. It can be used to group
  # all the transactions sent by a single shipper in the web interface.
  # If this options is not defined, the hostname is used.
EOF
cat <<EOF >> ${home}/topbeat.yml
  name: "${serverName}"

EOF
cat <<'EOF' >> ${home}/topbeat.yml
  # The tags of the shipper are included in their own field with each
  # transaction published. Tags make it easy to group servers by different
  # logical properties.
  tags: ["topbeat"]

  # Uncomment the following if you want to ignore transactions created
  # by the server on which the shipper is installed. This option is useful
  # to remove duplicates if shippers are installed on multiple servers.
  #ignore_outgoing: true

  # How often (in seconds) shippers are publishing their IPs to the topology map.
  # The default is 10 seconds.
  #refresh_topology_freq: 10

  # Expiration time (in seconds) of the IPs published by a shipper to the topology map.
  # All the IPs will be deleted afterwards. Note, that the value must be higher than
  # refresh_topology_freq. The default is 15 seconds.
  #topology_expire: 15

  # Configure local GeoIP database support.
  # If no paths are not configured geoip is disabled.
  #geoip:
    #paths:
    #  - "/usr/share/GeoIP/GeoLiteCity.dat"
    #  - "/usr/local/var/GeoIP/GeoLiteCity.dat"


############################# Logging #########################################

# There are three options for the log ouput: syslog, file, stderr.
# Under Windos systems, the log files are per default sent to the file output,
# under all other system per default to syslog.
logging:

  # Send all logging output to syslog. On Windows default is false, otherwise
  # default is true.
  #to_syslog: true

  # Write all logging output to files. Beats automatically rotate files if rotateeverybytes
  # limit is reached.
  #to_files: false

  # To enable logging to files, to_files option has to be set to true
  files:
    # The directory where the log files will written to.
    #path: /var/log/mybeat

    # The name of the files where the logs are written to.
    #name: mybeat

    # Configure log file size limit. If limit is reached, log file will be
    # automatically rotated
    rotateeverybytes: 10485760 # = 10MB

    # Number of rotated log files to keep. Oldest files will be deleted first.
    #keepfiles: 7

  # Enable debug output for selected components. To enable all selectors use ["*"]
  # Other available selectors are beat, publish, service
  # Multiple selectors can be chained.
  #selectors: [ ]

  # Sets log level. The default log level is error.
  # Available log levels are: critical, error, warning, info, debug
  #level: error
EOF

    ## if we have a tag, as it is optional
    if [ ! -z ${tag+x} ]; then
        sed -i'.bak' "s|  tags: .*|  tags: [\"topbeat\",\"${tag}\"]|" ${home}/topbeat.yml
        rm ${home}/topbeat.yml.bak
    fi

    ## ensure proper permissions
    chgrp -R ${user} ${home}
    chown -R ${user} ${home}
    chmod -R g+rwX ${home}

    ## install service
    sudo bash ${CURRENT_DIR}/installSupervisordConfig.sh --name "topbeat" --toexecute "topbeat --c ${home}/topbeat.yml" directory "${home}" --serviceuser "root"

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
