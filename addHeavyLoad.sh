#!/usr/bin/env bash
# Calls a function of the same name for each needed variable.
function global {
	for arg in "$@"
	do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
	done
}

function -h {
cat <<USAGE
USAGE: addHeavyLoad.sh (presented with defaults)

   This script receives no parameters and should only be used in testing. The intent of this process is to generate a massive ammount of load on the server.

USAGE
}; function --help { -h ;}

function options {
	while [[ ${1:+isset} ]]
	do
		case "$1" in
			--*)		err "No such option: $1"	;;
		esac
		shift
	done
}

function validate {
	echo "No validation to be completed as no options are enabled."
}

function process {
	wget -O prime.tar.gz http://www.mersenne.org/ftp_root/gimps/p95v289.linux64.tar.gz
 	tar -xf prime.tar.gz
  ./mprime -t
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
