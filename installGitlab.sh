#!/bin/bash -x
set -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installGitlab.sh (presented with defaults)
                             (--version "8.5.4")?
                             (--gitDataDir "/var/opt/gitlab/git-data")?
                             (--externalURL "http://ubuntu")? (use internal dns)

  Install and configure Gitlab.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --version)                version="$2"             ; shift ;;
      --gitDataDir)             gitDataDir="$2"             ; shift ;;
      --externalURL)            externalURL="$2"             ; shift ;;
      --*)                      err "No such option: $1" ;;
    esac
    shift
  done
}

function validate {
    if [ -z ${version+x} ]; then
        version="8.5.4"
        echo "** version not set, using default --> ${version}"
    fi
    if [ -z ${gitDataDir+x} ]; then
        gitDataDir="/var/opt/gitlab/git-data"
        echo "** gitDataDir not set, using default --> ${gitDataDir}"
    fi
    if [ -z ${externalURL+x} ]; then
        externalURL="http://ubuntu"
        echo "** externalURL not set, using default --> ${externalURL}"
    fi
}

function process {
    ## set instance details
    home=/opt/gitlab

    mkdir ${home}
    cd ${home}

    ## install required components, download gitlab version, unpackage/install gitlab
    curl -LJO https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/trusty/gitlab-ce_${version}-ce.0_amd64.deb/download
    sudo dpkg -i gitlab-ce_${version}-ce.0_amd64.deb
    sudo gitlab-ctl reconfigure

    ## Complete basic configuration changes
    sudo sed -i'.bak' "s|external_url http://ubuntu|external_url ${externalURL}|g" /etc/gitlab/gitlab.rb

    echo git_data_dir \"${gitDataDir}\" | sudo tee -a /etc/gitlab/gitlab.rb
    sudo mkdir ${gitDataDir}

    ## reconfigure gitlab to apply all changes
    sudo gitlab-ctl reconfigure

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
