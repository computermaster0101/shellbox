#!/bin/bash -x
set -o nounset -o pipefail

# Test to ensure we have java
command -v java >/dev/null 2>&1 || { echo "Java is required but it's not installed.  Aborting." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Git is required but it's not installed.  Aborting." >&2; exit 1; }

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<'USAGE'
USAGE: installDNSServer.sh (presented with defaults)
                            (--artifactGroup "")?
                            (--artifactName "")?
                            (--artifactVersion "")?
                            (--artifactDomainSuffix "")? (optional) (if provided please ensure it ends with /)
                            (--artifactRepository "releases")?(optional)(releases,snapshots)
                            (--artifactRepositoryHost "git@bitbucket.org:youraccount/gitmavenrepo.git")?(optional)
                            (--jvmArgs "-server -Xmx1536M -Xms1536M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts ")?
                            (--springArgs "")? (optional)
                            (--includeFat false)? (optional)
                            (--logsDirectory "/var/logs/${artifactName}")?(optional)(if provided please ensure it ends with /)
                            (--installDirectory "/opt/etc/${artifactName}")?(optional)(if provided please ensure it ends with /)

  Install and configure spring boot app server.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --artifactGroup)                  artifactGroup="$2"                      ; shift ;;
      --artifactName)                   artifactName="$2"                       ; shift ;;
      --artifactVersion)                artifactVersion="$2"                    ; shift ;;
      --artifactDomainSuffix)           artifactDomainSuffix="$2"               ; shift ;;
      --artifactRepository)             artifactRepository="$2"                 ; shift ;;
      --artifactRepositoryHost)         artifactRepositoryHost="$2"             ; shift ;;
      --jvmArgs)                        jvmArgs="$2"                            ; shift ;;
      --springArgs)                     springArgs="$2"                         ; shift ;;
      --includeFat)                     includeFat="$2"                         ; shift ;;
      --logsDirectory)                  logsDirectory="$2"                      ; shift ;;
      --installDirectory)               installDirectory="$2"                   ; shift ;;
      --*)                              err "No such option: $1"                        ;;
    esac
    shift
  done
}

function process {
    ## make user
    useradd -m ${artifactName}
    ## lock the user from remote logins
    passwd -l ${artifactName}

    mkdir -p ${logsDirectory}/
    mkdir -p ${installDirectory}/
    touch ${logsDirectory}/${artifactName}.log

    fat=
    if [ ! -z ${includeFat+x} ]; then
        fat="-fat"
    fi

    depth=4
    if [ "${artifactDomainSuffix}x" == "x" ]; then
        depth=3
    else
        artifactDomainSuffix="${artifactDomainSuffix}/"
    fi

    if [ -f ${installDirectory}/${artifactName}.jar ]; then
        sudo rm ${installDirectory}/${artifactName}.jar
    fi

    echo "${artifactVersion}" | grep -q -e "-"
    isSnapshot=$?
    versionInPath=${artifactVersion}
    if [ ${isSnapshot} -eq 0 ]; then ## if 0 means match
        versionInPath=$(echo "${versionInPath}" | cut -d'-' -f 1) ## just get version part not snapshot date
        versionInPath="${versionInPath}-SNAPSHOT"
    fi

    cd /tmp
    echo "downloading archive, using command -> "
    echo "        git archive --output ./${artifactName}-${versionInPath}.tar --remote=${artifactRepositoryHost} ${artifactRepository} ${artifactDomainSuffix}${artifactGroup}/${artifactName}/${versionInPath}/${artifactName}-${artifactVersion}${fat}.jar"
    git archive --output ./${artifactName}-${versionInPath}.tar --remote=${artifactRepositoryHost} ${artifactRepository} ${artifactDomainSuffix}${artifactGroup}/${artifactName}/${versionInPath}/${artifactName}-${artifactVersion}${fat}.jar
    tar -xf ./${artifactName}-${versionInPath}.tar --strip=${depth} -C ./
    mv ${artifactName}-${artifactVersion}${fat}.jar ${installDirectory}/${artifactName}.jar
    rm ./${artifactName}-${versionInPath}.tar

    chown -R ${artifactName}:${artifactName} ${logsDirectory}/
    chown -R ${artifactName}:${artifactName} ${installDirectory}/

    chmod -R g+rwX ${logsDirectory}/
    chmod -R g+rwX ${installDirectory}/

    COMMAND="java ${jvmArgs} -jar ${installDirectory}${artifactName}.jar ${springArgs}"
    echo "COMMAND : ${COMMAND}"
    ${CURRENT_DIR}/installSupervisordConfig.sh --name "${artifactName}" --toexecute "${COMMAND}" --serviceuser "${artifactName}"
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
        artifactRepositoryHost="git@bitbucket.org:mindsignited/maven-repo.git"
        echo "** artifactRepositoryHost not set, using default --> ${artifactRepositoryHost}"
    fi
    if [ -z ${jvmArgs+x} ]; then
        jvmArgs="-server -Xmx1536M -Xms1536M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts "
        echo "** jvmArgs not set, using default --> ${jvmArgs}"
    fi
    if [ -z ${springArgs+x} ]; then
        springArgs=""
        echo "** springArgs not set, using default --> ${springArgs}"
    fi
    if [ -z ${logsDirectory+x} ]; then
        logsDirectory="/var/logs/${artifactName}"
        echo "** logsDirectory not set, using default --> ${logsDirectory}"
    fi
    if [ -z ${installDirectory+x} ]; then
        installDirectory="/opt/etc/${artifactName}"
        echo "** installDirectory not set, using default --> ${installDirectory}"
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
