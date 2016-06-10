#!/usr/bin/env bash
# Calls a function of the same name for each needed variable.
function global {
  for arg in "$@"
  do [[ ${!arg+isset} ]] || eval "$arg="'"$('"$arg"')"'
  done
}

function -h {
cat <<USAGE
USAGE: setupEBSVolume.sh (presented with defaults)
                             (--device "")?
                             (--mount "")?

  Add device to fstab for auto-mount at system boot.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --device)    device="$2"                 ; shift ;;
      --mount)     mount="$2"                  ; shift ;;
      --*)         err "No such option: $1" ;;
    esac
    shift
  done
}

function process {

    ## only try to attach/format the EBS if it is present.
    file -s "${device}" >> /dev/null
    isDeviceAttached=$?
    if [ ${isDeviceAttached} -eq 0 ]; then
        echo "we have our EBS volume attached at ${device}"
        ## check to ensure we have a filesystem on EBS
        hasFileSystem=$(file -s "${device}")
        if [ "${hasFileSystem}" == "${device}: data" ]; then
            echo "formatting device as it is not formatted. formatting.."
            mkfs -t ext4 "${device}"
        else
            echo "device is already formatted.."
        fi

        ## add mount to fstab
        grep -q /etc/fstab -e "${device}"
        alreadyInFstab=$?
        if [ ${alreadyInFstab} -eq 1 ]; then ## if 1 means no match - not in fstab
            echo "device not in fstab, adding..."
            cp /etc/fstab /etc/fstab.orig
            echo "${device}       ${mount}   ext4    defaults,nofail,nobootwait        0       2" | tee -a /etc/fstab
        else
            echo "device already in fstab, continuing..."
        fi

        ## now ensure its mounted at this moment.
        grep -qs "${mount}" /proc/mounts
        mountRet=$?
        if [ ${mountRet} -eq 0 ]; then
          echo "device already mounted, continuing...."
        else
          echo "device is not mounted, mounting now...."
          mkdir -p "${mount}"
          mount "${device}" "${mount}"
          if [ $? -eq 0 ]; then
           echo "Mount success!"
          else
           echo "Something went wrong with the mount!!!"
          fi
        fi
    else
        echo "we do not have our EBS volume attached at ${device}!"
    fi


}

function validate {
    if [ -z ${device+x} ]; then
      echo "ERROR --> Must pass in a --device for proper functioning"
      exit 1
    fi
    if [ -z ${mount+x} ]; then
      echo "ERROR --> Must pass in a --mount for proper functioning"
      exit 1
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