#!/bin/bash -x
set -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: uploadAwsCert.sh (presented with defaults)
                             (--privateKey "")?
                             (--pubCrt "")?
                             (--chainCrt "")?

  Upload signed certificate to AWS.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --privateKey)            privateKey="$2"             ; shift ;;
      --publicCrt)             publicCrt="$2"              ; shift ;;
      --chainCrt)              chainCrt="$2"               ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function validateopts {
    if [ -z ${privateKey+x} ]; then
        echo "** privateKey not set but is required. Please specify --privateKey"
        exit 1
    fi
    if [ -z ${publicCrt+x} ]; then
        echo "** publicCrt not set but is required. Please specify --publicCrt"
        exit 1
    fi
    if [ -z ${chainCrt+x} ]; then
        echo "** chainCrt not set but is required. Please specify --chainCrt"
        exit 1
    fi
}

function process {
    name=${privateKey%%.*}

    echo "converting to pem format"
    openssl rsa -in ${privateKey} -out aws-${name}.pem
    openssl x509 -in ${publicCrt} -out aws-${name}.crt -outform PEM
    openssl x509 -in ${chainCrt} -out aws-chain-${name}.crt -outform PEM


    echo "uploading certificate ${name} to Amazon"
    aws iam upload-server-certificate \
    --certificate-body file://aws-${name}.crt \
    --private-key file://aws-${name}.pem \
    --certificate-chain file://aws-chain-${name}.crt \
    --server-certificate-name ${name}
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