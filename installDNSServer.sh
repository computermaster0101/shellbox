#!/bin/bash -x
set -o nounset -o pipefail


CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installDNSServer.sh (presented with defaults)
                            (--privateIpAddress "")?
                            (--subnetRouterAddress "10.0.2.1")?
                            (--reverseSubnetForZone "2.0.10")? NOTE: only need the first three octets for the zone
                            (--domain "")?
                            (--domainAws "ec2.internal")?
                            (--domainKeyAlgorithm "hmac-md5")?
                            (--domainKeySecret "")?

  Install and configure dns server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --privateIpAddress)               privateIpAddress="$2"                     ; shift ;;
      --subnetRouterAddress)            subnetRouterAddress="$2"                  ; shift ;;
      --reverseSubnetForZone)           reverseSubnetForZone="$2"                 ; shift ;;
      --domain)                         domain="$2"                               ; shift ;;
      --domainAws)                      domainAws="$2"                            ; shift ;;
      --domainKeyAlgorithm)             domainKeyAlgorithm="$2"                   ; shift ;;
      --domainKeySecret)                domainKeySecret="$2"                      ; shift ;;
      --*)                              err "No such option: $1"                          ;;
    esac
    shift
  done
}

function process {

    ## update /etc/hosts and add our server hostname to it.
    ## this is b/c we are going to host our own dns server
    ## locally, no need for AWS DNS which normally resolves
    ## our hostnames.  We cannot have two NS locally.
    ## This works for now, we could have a different more
    ## complex setup if needed.
    hostName=$(hostname)
    sudo su <<HERE
cat <<EOF >> /etc/hosts
127.0.0.1 ${hostName}
EOF
HERE

    sudo apt-get update -y
    sudo apt-get install -y bind9

    sudo touch /etc/dhcp/dhclient.conf
    sudo su <<HERE
cat <<EOF > /etc/dhcp/dhclient.conf

option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name "<hostname>";
supersede domain-name "${domain}";
supersede domain-search "${domain}","${domainAws}";
prepend domain-name-servers ${privateIpAddress};

EOF
HERE

    sudo touch /etc/bind/named.conf.local
    sudo su <<HERE
cat <<EOF > /etc/bind/named.conf.local

zone "${domain}" IN {
	type master;
	file "/etc/bind/zones/${domain}.db";
	allow-update { key "${domain}."; };
	journal "/var/lib/bind/${domain}.jnl";
};

zone "${reverseSubnetForZone}.in-addr.arpa" {
	type master;
	file "/etc/bind/zones/rev.${reverseSubnetForZone}.in-addr.arpa";
};

key "${domain}." {
	algorithm ${domainKeyAlgorithm};
	secret "${domainKeySecret}";
};

EOF
HERE

    sudo mkdir -p /etc/bind/zones

    sudo touch /etc/bind/zones/${domain}.db
    sudo echo '$TTL    604800' | sudo tee /etc/bind/zones/${domain}.db
    sudo su <<HERE
cat <<EOF >> /etc/bind/zones/${domain}.db
@       IN      SOA     ns.${domain}. root.${domain}. (
                         2013022000     ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.${domain}.
ns      IN      A       ${privateIpAddress}
router  IN      A       ${subnetRouterAddress}

EOF
HERE

    firstThreeOctets=$(echo "${privateIpAddress}" | sed 's/[^.]*$//')
    lastOctet=$(echo "${privateIpAddress}" | sed -r "s/${firstThreeOctets}//g")
    sudo touch /etc/bind/zones/rev.${reverseSubnetForZone}.in-addr.arpa
    echo '$TTL    604800' | sudo tee /etc/bind/zones/rev.${reverseSubnetForZone}.in-addr.arpa
    sudo su <<HERE
cat <<EOF >> /etc/bind/zones/rev.${reverseSubnetForZone}.in-addr.arpa
@       IN      SOA     ns.${domain}. root.${domain}. (
                         2013111301     ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       					IN      NS      ns.
${lastOctet}     IN      PTR     ns.${domain}.

EOF
HERE

    sudo chmod 0755 /etc/dhcp/dhclient.conf
    sudo chmod 0755 /etc/bind/named.conf.local
    sudo chmod -R 0755 /etc/bind/zones/

    sudo service bind9 restart
    sudo su <<HERE
nohup sh -c 'ifdown eth0 && ifup eth0' >/dev/null 2>&1
HERE
}

function validate {
    if [ -z ${privateIpAddress+x} ]; then
        echo "** You must provide --privateIpAddress '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${domain+x} ]; then
        echo "** You must provide --domain '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${domainKeySecret+x} ]; then
        echo "** You must provide --domainKeySecret '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${subnetRouterAddress+x} ]; then
        subnetRouterAddress="10.0.2.1"
        echo "** subnetRouterAddress not set, using default --> ${subnetRouterAddress}"
    fi
    if [ -z ${reverseSubnetForZone+x} ]; then
        reverseSubnetForZone="2.0.10"
        echo "** reverseSubnetForZone not set, using default --> ${reverseSubnetForZone}"
    fi
    if [ -z ${domainKeyAlgorithm+x} ]; then
        domainKeyAlgorithm="hmac-md5"
        echo "** domainKeyAlgorithm not set, using default --> ${domainKeyAlgorithm}"
    fi
    if [ -z ${domainAws+x} ]; then
        domainAws="ec2.internal"
        echo "** domainAws not set, using default --> ${domainAws}"
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
