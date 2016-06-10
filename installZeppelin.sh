#!/bin/bash -x
##
## Install Zeppelin Server.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installZeppelin.sh     (--adminUsername "")? (required)
                              (--masterHostname "")? (required)

  Install Zeppelin Server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --adminUsername)            adminUsername="$2"                ; shift ;;
      --masterHostname)           masterHostname="$2"               ; shift ;;
      --*)                        err "No such option: $1"                  ;;
    esac
    shift
  done
}

function process {
    echo "Installing Zeppelin service..."

    ##
    ## http://zeppelin.incubator.apache.org/docs/tutorial/tutorial.html
    ## https://github.com/apache/incubator-zeppelin
    ##

    cd /opt

    ## http://www.ignitedpeople.com/installing-maven-3-3-3-on-ubuntu-14/
    sudo add-apt-repository -y "deb http://ppa.launchpad.net/natecarlson/maven3/ubuntu precise main"
    sudo apt-get update
    sudo apt-get install -y openjdk-7-jdk git maven3 npm
    sudo ln -s /usr/bin/mvn3 /usr/bin/mvn

    sudo git clone https://github.com/apache/incubator-zeppelin.git
    cd incubator-zeppelin
    sudo mvn clean install -Dignite-version=1.2.0-incubating -DskipTests

    echo "Done installing Zeppelin service."
}

function validate {
    if [ -z ${adminUsername+x} ]; then
        echo "** We require --adminUsername! We do not provide defaults for this field. "
        exit 1
    fi
    if [ -z ${masterHostname+x} ]; then
        echo "** We require --masterHostname! We do not provide defaults for this field. "
        exit 1
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
