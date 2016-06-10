#!/bin/bash -x
set -o nounset -o pipefail

## Test to ensure we have openssl!!
command -v openssl >/dev/null 2>&1 || { echo "Openssl Required but it's not installed and/or on PATH.  Aborting." >&2; exit 1; }

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: generateCSR.sh (presented with defaults)
                            (--country "")?(required) Country Name (2 letter code)
                            (--state "")?(required) State or Province Name (full name)
                            (--city "")?(required) Locality Name (eg, city)(full name)
                            (--organization "")?(required) The exact legal name of the organization. Do not abbreviate the organization name.
                            (--organizationalUnit "")?(required)
                            (--commonName "")?(required)
                            (--email "")?(required)
                            (--wildcard false)?(optional)

  Generate CSR with custom defaults.

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
      --email)                    email="$2"                    ; shift ;;
      --wildcard)                 wildcard="$2"                 ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
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
    if [ -z ${email+x} ]; then
        echo "** You must provide --email '' so we know what to configure. "
        exit 1
    fi
    if [ -z ${wildcard+x} ]; then
        wildcard=false
        echo "** wildcard not set, using default --> ${wildcard}"
    fi
}

function process {
    echo "Generating CSR...."
    adjustedCommonName=$(echo "${commonName}")
    if [ "${wildcard}" == "true" ]; then
        echo "CSR using Wildcard!"
        adjustedCommonName=$(echo "*.${commonName}")
    fi
    mkdir -p ${commonName}/
    echo "Generating CSR using subject line :"
    echo
    echo "/C=${country}/ST=${state}/L=${city}/O=${organization}/OU=${organizationalUnit}/CN=${adjustedCommonName}/emailAddress=${email}"
    echo
    echo "Please wait..."
    openssl genrsa -out ${commonName}/${commonName}.key 2048
    openssl req -new -key ${commonName}/${commonName}.key \
                     -out ${commonName}/${commonName}.csr \
                     -subj "/C=${country}/ST=${state}/L=${city}/O=${organization}/OU=${organizationalUnit}/CN=${adjustedCommonName}/emailAddress=${email}"

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