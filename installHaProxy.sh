#!/bin/bash -x
##
## Install HaProxy.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installHaProxy.sh    (--country "")?(required) Country Name (2 letter code)
                            (--state "")?(required) State or Province Name (full name)
                            (--city "")?(required) Locality Name (eg, city)(full name)
                            (--organization "")?(required) The exact legal name of the organization. Do not abbreviate the organization name.
                            (--organizationalUnit "")?(required)
                            (--commonName "")?(required)
                            (--wildcard false)?(optional)

  Install HaProxy.

  WARNING: Script requires ubuntu 15.04 or greater, as we require haproxy to be available via apt.

  If you'd like to use a wildcard certificate, then please specify it using the --wildcard and we'll place
  the *.${commonName} for you.  This is b/c we use the commonName for the certificate name.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --country)                  country="$2"                  ; shift ;;
      --state)                    state="$2"                    ; shift ;;
      --city)                     city="$2"                     ; shift ;;
      --organization)             organization="$2"             ; shift ;;
      --organizationalUnit)       organizationalUnit="$2"       ; shift ;;
      --commonName)               commonName="$2"               ; shift ;;
      --wildcard)                 wildcard="$2"                 ; shift ;;
      --*)                        err "No such option: $1"              ;;
    esac
    shift
  done
}

function process {
    echo "Installing HaProxy... "
    sudo add-apt-repository -y ppa:vbernat/haproxy-1.5
    sudo apt-get -y update
    sudo apt-get install -y haproxy openssl

    if [ ! -f /etc/ssl/${commonName}/${commonName}.pem ]; then
        adjustedCommonName=$(echo "${commonName}")
        if [ "${wildcard}" == "true" ]; then
            adjustedCommonName=$(echo "*.${commonName}")
        fi
        sudo mkdir -p /etc/ssl/${commonName}/
        sudo openssl genrsa -out /etc/ssl/${commonName}/${commonName}.key 2048
        sudo openssl req -new -key /etc/ssl/${commonName}/${commonName}.key \
                         -out /etc/ssl/${commonName}/${commonName}.csr \
                         -subj "/C=${country}/ST=${state}/L=${city}/O=${organization}/OU=${organizationalUnit}/CN=${adjustedCommonName}"
        sudo openssl x509 -req -days 36500 -in /etc/ssl/${commonName}/${commonName}.csr \
                         -signkey /etc/ssl/${commonName}/${commonName}.key \
                         -out /etc/ssl/${commonName}/${commonName}.crt
        sudo cat /etc/ssl/${commonName}/${commonName}.crt /etc/ssl/${commonName}/${commonName}.key | sudo tee /etc/ssl/${commonName}/${commonName}.pem
        sudo chmod -R 0644 /etc/ssl/${commonName}/
    fi

sudo cat <<EOF > /etc/haproxy/haproxy.cfg
global
	log 127.0.0.1	local0
	log 127.0.0.1	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
    maxconn 20000
    user haproxy
    group haproxy
	daemon

	# Default SSL material locations
#	ca-base /etc/ssl/certs
#	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
#	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
#	ssl-default-bind-options no-sslv3

    #debug
    #quiet

defaults
    log     global
    mode    http
    retries 3
    timeout client 30s
    timeout connect 5s
    timeout server 30s
    timeout tunnel 1h
    option dontlognull
    option forwardfor
    option http-server-close
    option httplog
    balance  roundrobin

    # Set up application listeners here.

    frontend http
    maxconn 20000
    bind 0.0.0.0:80
    default_backend servers-http

    frontend https
    maxconn 20000
    bind 0.0.0.0:443 ssl crt /etc/ssl/${commonName}/${commonName}.pem
    reqadd X-Forwarded-Proto:\ https
    default_backend servers-http

    listen admin 0.0.0.0:22002
    mode http
    stats uri /

    backend servers-http
EOF

    sudo service haproxy restart
}

function validate {
    if [ -z ${country+x} ]; then
        echo "** You must provide --country '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${state+x} ]; then
        echo "** You must provide --state '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${city+x} ]; then
        echo "** You must provide --city '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${organization+x} ]; then
        echo "** You must provide --organization '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${organizationalUnit+x} ]; then
        echo "** You must provide --organizationalUnit '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${commonName+x} ]; then
        echo "** You must provide --commonName '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${wildcard+x} ]; then
        wildcard=false
        echo "** wildcard not set, using default --> ${wildcard}"
    fi
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

