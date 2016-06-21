#!/bin/bash -x
##
## Install Tomcat 8 and place into /opt/tomcat8.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Git is required but it's not installed.  Aborting." >&2; exit 1; }

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installTomcatApp.sh      (--artifactGroup "")?
                                (--artifactName "")?
                                (--artifactVersion "")?
                                (--artifactDomainSuffix "")? (optional) (if provided please ensure it ends with /)
                                (--artifactRepository "releases")?(optional)(releases,snapshots)
                                (--artifactRepositoryHost "git@bitbucket.org:yourrepo/mavenrepo.git")?(optional)
                                (--artifactType "war")?(optional)
                                (--tomcatMajorVersion "8")?(optional)
                                (--logsDirectory "/var/logs/${artifactName}")?(optional)

  Install A Tomcat App.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --artifactGroup)            artifactGroup="$2"             ; shift ;;
      --artifactName)             artifactName="$2"              ; shift ;;
      --artifactVersion)          artifactVersion="$2"           ; shift ;;
      --artifactDomainSuffix)     artifactDomainSuffix="$2"      ; shift ;;
      --artifactRepository)       artifactRepository="$2"        ; shift ;;
      --artifactRepositoryHost)   artifactRepositoryHost="$2"    ; shift ;;
      --artifactType)             artifactType="$2"              ; shift ;;
      --tomcatMajorVersion)       tomcatMajorVersion="$2"        ; shift ;;
      --logsDirectory)            logsDirectory="$2"             ; shift ;;
      --*)                        err "No such option: $1"               ;;
    esac
    shift
  done
}

function process {
    echo "Installing Tomcat ${tomcatMajorVersion} App... "

    ## Ensure supervisor is stopped since it doesn't work right otherwise.
    echo "Stopping supervisor, waiting for services to stop...."
    sudo service supervisor stop
    sleep 60 ## lets ensure we give things time to stop
    ## do we need to kill java?
    if [ "$(pidof java)x" != "x" ]; then
        echo "lingering java processes!  killing them before continuing."
        sudo kill $(pidof java) ## this is a sanity check as all services / those using java / should be down.
        sleep 10 ## lets ensure we give things time to stop
    else
        echo "no lingering java processes!"
    fi
    echo "continuing...."

    ## tomcat home
    user="tomcat${tomcatMajorVersion}"
    export CATALINA_HOME=/opt/tomcat${tomcatMajorVersion}

    depth=4
    if [ "${artifactDomainSuffix}x" == "x" ]; then
        depth=3
    else
        artifactDomainSuffix="${artifactDomainSuffix}/"
    fi

    if [ -f ${CATALINA_HOME}/webapps/${artifactName}.${artifactType} ]; then
        sudo rm -r ${CATALINA_HOME}/webapps/${artifactName}*
    fi

    versionInPath=${artifactVersion}
    if [ $(echo "${artifactVersion}" | grep -c "-") -eq 0 ]; then
        echo "We have a Release Version String, no need to parse. "
    else
        echo "We have a Snapshot Version String, parsing..."
        versionInPath=$(echo "${versionInPath}" | cut -d'-' -f 1) ## just get version part not snapshot date
        versionInPath="${versionInPath}-SNAPSHOT"
    fi

    cd /tmp
    echo "downloading archive, using command -> "
    echo "        git archive --output ./${artifactName}-${versionInPath}.tar --remote=${artifactRepositoryHost} ${artifactRepository} ${artifactDomainSuffix}${artifactGroup}/${artifactName}/${versionInPath}/${artifactName}-${artifactVersion}.${artifactType}"
    sudo git archive --output ./${artifactName}-${versionInPath}.tar --remote=${artifactRepositoryHost} ${artifactRepository} ${artifactDomainSuffix}${artifactGroup}/${artifactName}/${versionInPath}/${artifactName}-${artifactVersion}.${artifactType}
    sudo tar -xf ./${artifactName}-${versionInPath}.tar --strip=${depth} -C ./
    sudo mv ./${artifactName}-${artifactVersion}.${artifactType} ${CATALINA_HOME}/webapps/${artifactName}.${artifactType}
    sudo rm ./${artifactName}-${versionInPath}.tar

    ## ensure proper permissions
    sudo chown -R ${user}:${user} ${CATALINA_HOME}
    sudo chmod -R g+rwX ${CATALINA_HOME}

    sudo mkdir -p ${logsDirectory}
    sudo chown -R ${user}:${user} ${logsDirectory}
    sudo chmod -R g+rwX ${logsDirectory}

    ## now we start supervisor back up.
    echo "Starting supervisor, waiting for services to start...."
    sudo service supervisor start
    sleep 60 ## lets ensure we give things time to start
}

function validate {
    if [ -z ${artifactGroup+x} ]; then
        echo "** You must provide --artifactGroup '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${artifactName+x} ]; then
        echo "** You must provide --artifactName '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${artifactVersion+x} ]; then
        echo "** You must provide --artifactVersion '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${artifactDomainSuffix+x} ]; then
        artifactDomainSuffix=""
        echo "** artifactDomainSuffix not set, using default --> ${artifactDomainSuffix}"
    fi
    if [ -z ${artifactRepository+x} ]; then
        artifactRepository="releases"
        echo "** artifactRepository not set, using default --> ${artifactRepository}"
    fi
    if [ -z ${artifactRepositoryHost+x} ]; then
        echo "** You must provide --artifactRepositoryHost '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${artifactType+x} ]; then
        artifactType="war"
        echo "** artifactType not set, using default --> ${artifactType}"
    fi
    if [ -z ${tomcatMajorVersion+x} ]; then
        tomcatMajorVersion="8"
        echo "** tomcatMajorVersion not set, using default --> ${tomcatMajorVersion}"
    fi
    if [ -z ${logsDirectory+x} ]; then
        logsDirectory="/var/logs/${artifactName}"
        echo "** logsDirectory not set, using default --> ${logsDirectory}"
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
