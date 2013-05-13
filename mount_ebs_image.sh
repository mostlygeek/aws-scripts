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

function do_mount {
    mount ${DEVICE} $IMGLOC || { echo "Error mounting the spec'd volume." >&2; exit; }

    if mount | grep -q ${IMGLOC}; then
        mkdir -p $IMGLOC/{dev,etc,proc,sys}
        mkdir -p $IMGLOC/var/{cache,log,lock,lib/rpm}
    
        for i in console null zero urandom; do
            /sbin/MAKEDEV -d $IMGLOC/dev -x $i
        done
    
        for i in /{dev{,/pts,/shm},proc,sys}; do
            mount -o bind $i ${IMGLOC}$i
        done
    else
        echo "Problem mounting device $DEVICE... Bailing out" >&2
        exit
    fi
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
                    echo "Error $OPTARG is already mounted" >&2
                    exit
                else
                    IMGLOC=$OPTARG
                fi
            else
                read -e -N 1 -p "$OPTARG doesn't exist. Would you like me to create it? (y/n)" CREATE
                if echo $CREATE | grep -iq y; then
                    mkdir -p $OPTARG || { echo "Could not create $OPTARG. Fix this and try again" >&2; exit; }
                    IMGLOC=$OPTARG
                else
                    echo "Could not parse your response. Bailing out." >&2
                    exit;
                fi
            fi

            # trim trailing slash if it exists
            IMGLOC=${IMGLOC%/}
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

do_mount
