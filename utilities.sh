#!/bin/bash

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

function msg { out "$*" >&2 ;}
function err { local x=$? ; msg "$*" ; return $(( $x == 0 ? 1 : $x )) ;}
function out { printf '%s\n' "$*" ;}

function globals {
  export LC_ALL=en_US.UTF-8
}; globals

# Calls a function of the same name for each needed variable.
function global {
  for arg in "$@"
  do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
  done
}
