#!/bin/bash -x
set -o errexit -o nounset -o pipefail
function -h {
cat <<USAGE
 USAGE: mesosflexinstall (--rel <mesos-version>)?
                         (--slave-hostname <SLAVE_HOSTNAME>)?

  Install and configure Mesos with Zookeeper support.

USAGE
}; function --help { -h ;}


function main {
  options "$@"
  install_mesos
  configure_slave
}

function globals {
  export LC_ALL=en_US.UTF-8
}; globals

# Calls a function of the same name for each needed variable.
function global {
  for arg in "$@"
  do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
  done
}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --rel)            rel="$2"                 ; shift ;;
      --slave-hostname) slave_hostname="$2"      ; shift ;; # See: MESOS-825
      --*)              err "No such option: $1" ;;
    esac
    shift
  done
}

function install_mesos {
  global os_release
  case "$os_release" in
    ubuntu/14.04)      install_with_apt "trusty" ;;
    *)                 err "No support for $os_release at this time." ;;
  esac
}

function configure_slave {
  if [[ ${slave_hostname+isset} ]]
  then
    mkdir -p /etc/mesos-slave
    echo "$slave_hostname" > /etc/mesos-slave/hostname
  fi
}

function install_apt_source {
  echo "deb http://repos.mesosphere.io/ubuntu/ $1 main" |
    as_root tee /etc/apt/sources.list.d/mesosphere.list
  as_root apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
  as_root apt-get update
}

function install_with_apt {
  apt_ curl unzip
  install_apt_source $1

  ## Install zookeeper
  apt_ zookeeperd zookeeper zookeeper-bin
  echo 1 | sudo dd of=/var/lib/zookeeper/myid

  ## Install and run Docker
  ## http://docs.docker.io/installation/ubuntulinux/ for more details
  apt_ docker.io
  as_root ln -sf /usr/bin/docker.io /usr/local/bin/docker
  as_root sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io

  ## Pull test docker image
  sudo docker pull libmesos/ubuntu

  ## Note: Version 0.19.0+ of Mesos is required;. It this version that introduced External Containerization (previously referred to as Isolators).
  ## Deimos (a required component of this technology stack) is one of the first external containerizers and requires this version to function.
  ##       Installation and Configuration of Mesos 0.19
  curl -fL http://downloads.mesosphere.io/master/ubuntu/14.04/mesos_0.19.0~ubuntu14.04%2B1_amd64.deb -o /tmp/mesos.deb
  as_root dpkg -i /tmp/mesos.deb

  as_root mkdir -p /etc/mesos-master
  echo in_memory | as_root dd of=/etc/mesos-master/registry

  ## Mesos Python egg for use in authoring frameworks
  curl -fL http://downloads.mesosphere.io/master/ubuntu/14.04/mesos-0.19.0_rc2-py2.7-linux-x86_64.egg -o /tmp/mesos.egg
  as_root easy_install /tmp/mesos.egg

 ## Installation and Configuration of Marathon
 curl -fL http://downloads.mesosphere.io/marathon/marathon_0.5.0-xcon2_noarch.deb -o /tmp/marathon.deb
 as_root dpkg -i /tmp/marathon.deb

 ## Restarting your environment. At this point, ensure all services have started (or restarted).
 as_root initctl reload-configuration
 as_root start docker.io || as_root restart docker.io
 as_root start zookeeper || as_root restart zookeeper
 as_root start mesos-master || as_root restart mesos-master
 as_root start mesos-slave || as_root restart mesos-slave

 ## Installation and configuration of Deimos. Deimos can be installed using the convenience of Python's pip installation tool.
 as_root pip install deimos

 ## Configuration of Mesos to use Deimos
 as_root mkdir -p /etc/mesos-slave

 ## Configure Deimos as a containerizer
 echo /usr/local/bin/deimos | as_root dd of=/etc/mesos-slave/containerizer_path
 echo external              | as_root dd of=/etc/mesos-slave/isolation

  ## Restart Marathon.
  as_root initctl reload-configuration
  as_root start marathon || as_root restart marathon
}

function apt_ {
  as_root env DEBIAN_FRONTEND=noninteractive aptitude update
  as_root env DEBIAN_FRONTEND=noninteractive aptitude install -y "$@"
}

function as_root {
  if [[ $(id -u) = 0 ]]
  then "$@"
  else sudo "$@"
  fi
}

function os_release {
  msg "Trying /etc/os-release..."
  if [[ -f /etc/os-release ]]
  then
    ( source /etc/os-release && display_version "$ID" "$VERSION_ID" )
    return 0
  fi
  msg "Trying /etc/redhat-release..."
  if [[ -f /etc/redhat-release ]]
  then
    # Seems to be formatted as: <distro> release <version> (<remark>)
    #                           CentOS release 6.3 (Final)
    if [[ $(cat /etc/redhat-release) =~ \
          ^(.+)' '+release' '+([^ ]+)' '+'('[^')']+')'$ ]]
    then
      local os
      case "${BASH_REMATCH[1]}" in
        'Red Hat '*) os=RedHat ;;
        *)           os="${BASH_REMATCH[1]}" ;;
      esac
      display_version "$os" "${BASH_REMATCH[2]}"
      return 0
    else
      err "/etc/redhat-release not like: <distro> release <version> (<remark>)"
    fi
  fi
  if which sw_vers &> /dev/null
  then
    local product="$(sw_vers -productName)"
    case "$product" in
      'Mac OS X') display_version MacOSX "$(sw_vers -productVersion)" ;;
      *) err "Expecting productName to be 'Mac OS X', not '$product'!";;
    esac
    return 0
  fi
  err "Could not determine OS version!"
}

function display_version {
  local os="$( tr A-Z a-z <<<"$1" )" version="$( tr A-Z a-z <<<"$2" )"
  case "$os" in
    redhat|centos|debian) out "$os/${version%%.*}" ;;   # Ignore minor versions
    macosx)               out "$os/${version%.*}" ;;  # Ignore bug fix releases
    *)                    out "$os/$version" ;;
  esac
}

function msg { out "$*" >&2 ;}
function err { local x=$? ; msg "$*" ; return $(( $x == 0 ? 1 : $x )) ;}
function out { printf '%s\n' "$*" ;}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
