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
                             (--bitbucketOptions "false")?
                             (--bitbucketOAuthKey "")?
                             (--bitbucketOAuthSecret "")?


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
      --bitbucketOptions)       bitbucketOptions="$2"           ; shift ;;
      --bitbucketRSA)           bitbucketRSA="$2"             ; shift ;;
      --bitbucketRSApub)        bitbucketRSApub="$2"             ; shift ;;
      --bitbucketOAuthKey)      bitbucketOAuthKey="$2"             ; shift ;;
      --bitbucketOAuthSecret)   bitbucketOAuthSecret="$2"             ; shift ;;
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
    # bitbucket options
    if [ ${bitbucketOptions}+x} ]; then
        bitbucketOptions="false"
        echo "** bitbucketRSA not set and will be generated automatically."
    fi
    if [ ${bitbucketOptions} == true ] & [ -z ${bitbucketRSA+x} ]; then
        bitbucketRSA=""
        echo "** bitbucketRSA not set and will be generated automatically."
    fi
    if [ ${bitbucketOptions} == true ] & [ -z ${bitbucketRSApub+x} ]; then
        bitbucketRSApub=""
        echo "** bitbucketRSApub not set and will be generated automatically."
    fi
    if [ ${bitbucketOptions} == true ] & [ -z ${bitbucketOAuthKey+x} ]; then
        echo "** bitbucketOAuthKey is not set but is required. Exiting now."
        exit 1;
    fi
    if [ ${bitbucketOptions} == true ] & [ -z ${bitbucketOAuthSecret+x} ]; then
        echo "** bitbucketOAuthSecret is not set but is required. Exiting now."
        exit 1;
    fi
}

function process {
    ## set instance details
    home=/opt/gitlab

    mkdir ${home}
    cd ${home}
#   # install required components, download gitlab version, unpackage/install gitlab
    sudo apt-get install -y curl openssh-server ca-certificates
    curl -LJO https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/trusty/gitlab-ce_${version}-ce.0_amd64.deb/download
    sudo dpkg -i gitlab-ce_${version}-ce.0_amd64.deb
    sudo gitlab-ctl reconfigure

    # Complete basic configuration changes
    sudo sed -i'.bak' "s|external_url http://ubuntu|external_url ${externalURL}|g" /etc/gitlab/gitlab.rb

#    echo git_data_dir "${gitDataDir}" | sudo tee -a /etc/gitlab/gitlab.rb
    sudo mkdir ${gitDataDir}

cat <<EOF >> /etc/gitlab/gitlab.rb
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_providers'] = [
    {
        "name" => "bitbucket",
        "app_id" => "${bitbucketOAuthKey}",
        "app_secret" => "${bitbucketOAuthSecret}",
        "URL" => "https://bitbucket.org"
    }
]
EOF

    # Setup ssh key to allow repository importing.
    # Note: Do not add an ssh or deployment keys to butbucket or to gitlab. All key management should be handled automatically

    # Generate certificate key and store the results for later use
    sudo -u git -H ssh-keygen
    sudo -u git -H ssh -Tv bitbucket.org
    bitbucketRSA=$(sudo cat /var/opt/gitlab/.ssh/id_rsa)
    bitbucketRSApub=$(sudo cat /var/opt/gitlab/.ssh/id_rsa.pub)
    bitbucketKnownhost=$(sudo cat /var/opt/gitlab/.ssh/knownhosts)


# Create config file for gitlab to use the created keys for the git user.
# Note: The git users home directory is automatically redirected to /var/opt/gitlab. This is correct.
# To clarify, by default ~/ is /var/opt/gitlab for the git user and does not need to be changed.
    sudo touch  /var/opt/gitlab/.ssh/config
cat <<EOF >> /var/opt/gitlab/.ssh/config
Host bitbucket.org
  IdentityFile ~/.ssh/bitbucket_rsa
  User git
EOF

    # Setup bitbucket repository integration
    # Note: Again, do not add any keys to bitbucket. Gitlab will do this automatically when ever needed.
    #       Adding the key to any location in bitbucket will result in permission related errors.
cat <<EOF >> /etc/gitlab/gitlab.rb
gitlab_rails['bitbucket'] = {
    'known_hosts_key' => '${bitbucketKnownhost}',
    'private_key' => '${bitbucketRSA}',
    'public_key' => '${bitbucketRSApub}'}
EOF

    # reconfigure gitlab to apply all changes
    sudo gitlab-ctl reconfigure

#    we need to add to the setup these settings
#nginx['listen_port'] = 80 # override only if you use a reverse proxy: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#setting-the-nginx-listen-port
#nginx['listen_https'] = false # override only if your reverse proxy internally communicates over HTTP: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#supporting$
#nginx['proxy_set_headers'] = {
# "X-Forwarded-Proto" => "https",
# "X-Forwarded-Ssl" => "on"
#}
#

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
