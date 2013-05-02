#!/bin/sh

# 
# Designed for EC2 instances, it will create a 2GB swap partition in 
# /media/ephemeral0/swapfile if there is no swap 
#

BASE="/media/ephemeral0"
SWAPFILE="$BASE/swapfile"

# Detect if swap currently exists
# for m1.small and c1.medium an ephemeral swap parition is
# automatically available
SWAP=$(swapon -s | grep '^/' | wc -l)
if [ $SWAP -gt 0 ]; then
    exit 0
fi

# just enable the swap if it exists and is the correct size
if [ -e $SWAPFILE ]; then
    if [ $(stat --terse $SWAPFILE | awk '{print $2}') -eq 2147483648 ]; then
        echo "Enabling swapfile: $SWAPFILE"
        swapon $SWAPFILE
        exit 0
    fi
fi

if [ ! -d $BASE ]; then
    echo "$BASE does not exist. No where to create swapfile"
    exit 1
fi

echo "Creating 2GB Swap file at $SWAPFILE"

dd if=/dev/zero of=$SWAPFILE bs=4k count=524288
mkswap $SWAPFILE
swapon $SWAPFILE
