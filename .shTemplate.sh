#!/usr/bin/env bash
# Calls a function of the same name for each needed variable.
function global {
	for arg in "$@"
	do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
	done
}

function -h {
cat <<USAGE
USAGE: FILE_NAME_GOES_HERE.sh (presented with defaults)
			(--OPTION1 "DEFAULT")?
			(--OPTION2 "DEFAULT")?

   INSERT A BRIEF DESCRIPTION OF WHAT THIS IS FOR.

USAGE
}; function --help { -h ;}

function options {
	while [[ ${1:+isset} ]]
	do
		case "$1" in
			--OPTION1)	OPTION_VAR="$2"		; shift ;;
			--OPTION2)	OPTION_VAR="$2"		; shift ;;
			--*)		err "No such option: $1"	;;
		esac
		shift
	done
}

function validate {
	if [ -z ${OPTION1+x} ]; then
		echo "ERROR --> Must pass in a --OPTION1 for proper functioning"
		exit 1
	fi

	if [ -z ${OPTION2+x} ]; then
		echo "ERROR --> Must pass in a --OPTION2 for proper functioning"
		exit 1
	fi
}

function process {
	echo INSERT PROCESS CODE HERE COMPLETE WITH LOGGING.
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
