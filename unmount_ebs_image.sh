#!/bin/bash
IMGLOC=
DEVICE=

function usage {

    if test -n "$IMGLOC"; then
        if mount | grep $IMGLOC; then
            unmount > /dev/null 2>&1
        fi
    fi

    cat <<EOF >&2
      Usage is: $0  -d <device> -i <directory for image>
      
      Where:
       -d  = Device to be used in /dev/<devicename> format (ex. /dev/sdb)

       -h  = Help (this message)

       -i  = Directory where the specified device's first partition will be mounted (ex. /mnt/image).
             If this directory doesn't exist, the script will prompt you to create it.

EOF
exit
}

function unmount {

    echo "Unmounting ${DEVICE}"
    for i in /{dev{/shm,/pts,},sys,proc,}
    do
        umount ${IMGLOC}${i}
        sleep 1
    done

}


while getopts :d:hi: ARGS; do
    case $ARGS in
        d)
            if  test -L /sys/block/${OPTARG#/dev/}; then
                DEVICE=$OPTARG
            else
                echo "$OPTARG is an invalid device" >&2
                usage
            fi
            ;;
        i)
            if [ -d $OPTARG ]; then
                if mount  | grep -E "$OPTARG "; then
                    IMGLOC=$OPTARG
                    IMGLOC=${IMGLOC%/}
                else 
                    echo "$OPTARG is not mounted. Bailing out" >&2
                fi
            else
                echo "$OPTARG does not exist! Bailing out." >&2
                exit;
            fi
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option!" >&2
            usage
            ;;
    esac
done
test -z "$DEVICE" && { echo "DEVICE is not set. Exiting" >&2; usage; }
test -z "$IMGLOC" && { echo "IMGLOC is not set. Exiting" >&2; usage; }

unmount
