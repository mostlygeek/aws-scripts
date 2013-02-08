#!/bin/bash


function usage(){

    cat <<"EOF"
    Usage is: $0 -d <device> -i <directory for image>
    Where:
    -d  = Device to be used in /dev/<devicename> format (ex. /dev/sdb)
    -i  = Directory where the specified device's first partition will be mouted (ex. /mnt/image)

    This program assumes that the drive is partitioned like so:
    /dev/<device>1 = /
    /dev/<device>2 = swap

    No other configuration will work properly.
EOF

}

function install_prereqs(){

    yum -y -q -e0 install e2fsprogs unzip MAKEDEV

}


function main(){

    test -z "$DEVICE" && { echo "DEVICE is not set. Exiting"; exit; }
    test -z "$IMGLOC" && { echo "IMGLOC is not set. Exiting"; exit; }
    install_prereqs
    drive_prep
    stage1_install
    stage2_install
    final_drive_prep
    umount

}

function create_partitions(){

    parted $DEVICE --script mklabel msdos
    parted $DEVICE --script -- unit GB mkpart primary ext4 1 18
    parted $DEVICE --script -- unit GB mkpart primary ext4 18 -1
    parted $DEVICE --script -- set 1 boot

}

function make_filesystems() {
    
   [ -b ${DEVICE}1 ] && \
       mke2fs -t ext4 -L ROOT -O extent -O sparse_super ${DEVICE}1 || \
         { echo "${DEVICE}1 not found"; exit} }
   mkswap -L exb-swap ${DEVICES}2

}

function drive_prep(){
    
    create_partitions
    make_filesystems
    mount ${DEVICE}1 $IMGLOC > /dev/null 2>&1 || { echo "Error mounting the spec'd volume."; exit; }
    ISMOUNTED=$(mount | grep -q ${IMGLOC}; echo $?)
    if [[ "$ISMOUNTED" -eq "0" ]]; then
        mkdir -p $IMGLOC/{dev,etc,proc,sys}
        mkdir -p $IMGLOC/var/{cache,log,lock,lib/rpm}
        for i in console null zero urandom
        do
            /sbin/MAKEDEV -d $IMGLOC/dev -x $i
        done
        for i in /{dev{,/pts,/shm},proc,sys}
        do
            echo mount -o bind $i ${IMGLOC}$i
        done
    else
        echo "Problem mounting device $DEVICE... Bailing out"
        exit
    fi
    rpm --rebuilddb --root=${IMGLOC}

}

function stage1_install() {

    # Build enough of an env that all the steps in stage2 will run as expected in a chroot

rpm -ivh --root=${IMGLOC}/ --nodeps  http://ftp.scientificlinux.org/linux/scientific/6.2/x86_64/os/Packages/sl-release-6.2-1.1.x86_64.rpm

cat > ${IMGLOC}/etc/yum.conf <<'EOF'
[main]
cachedir=/var/cache/yum/$basearch/$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=3
multilib_policy=best
distroverpkg=sl-release
EOF

echo "Installing base packages for chroot"
yum -e0 -c ${IMGLOC}/etc/yum.conf --installroot=${IMGLOC} install -y rpm-build yum openssh-server dhclient
yum -e0 -c ${IMGLOC}/etc/yum.conf --installroot=${IMGLOC} install -y http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-6.noarch.rpm

cat > ${IMGLOC}/etc/sysconfig/network-scripts/ifcfg-eth0 <<'EOF'
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
TYPE=Ethernet
USERCTL=yes
PEERDNS=yes
IPV6INIT=no
EOF

cat > ${IMGLOC}/etc/sysconfig/network <<'EOF'
NETWORKING=yes
HOSTNAME=localhost.localdomain
NOZEROCONF=yes
NETWORKING_IPV6=no
IPV6INIT=no
IPV6_ROUTER=no
IPV6_AUTOCONF=no
IPV6FORWARDING=no
IPV6TO4INIT=no
IPV6_CONTROL_RADVD=no
EOF

# copies build host's resolv.conf into the image
cp  /etc/resolv.conf ${IMGLOC}/etc/resolv.conf

# Be aware, this will not work for instance store AMI's
cat > ${IMGLOC}/etc/fstab <<'EOF'
/dev/xvde1     /         ext3    defaults,noatime  1    1
tmpfs          /dev/shm  tmpfs   defaults          0    0
devpts         /dev/pts  devpts  gid=5,mode=620    0    0
sysfs          /sys      sysfs   defaults          0    0
proc           /proc     proc    defaults          0    0
LABEL=ebs-swap none      swap    sw                0    0

EOF

# Create the shell script that will run in stage2 chroot
echo "Creating stage2 script"
cat > ${IMGLOC}/root/stage2.sh <<'STAGE2EOF'

echo "   CHROOT - Installing base and core"
yum -e0 -y -q groupinstall base core
echo "   CHROOT - Installing supplemental packages"
yum -e0 -y install -q --enablerepo=puppetlabs-products,puppetlabs-deps \
java-1.6.0-openjdk epel-release rpmforge-release automake dhclient \
e2fsprogs gcc git grub iotop libcgroup ltrace mailx nc net-snmp \
nss-pam-ldapd ntp wget epel-release rpmforge-release ruby rubygems \
screen strace sudo svn tuned tuned-utils vim-enhanced yum-utils zsh \
puppet-2.7.13 augeas-libs facter ruby-augeas ruby-shadow libselinux-ruby \
libselinux-python *openssh* yum-plugin-fastestmirror.noarch python-cheetah \
python-configobj python-pip python-virtualenv supervisor \
yum-plugin-fastestmirror
echo "   CHROOT - Installing cloud init"
yum -e0 -y -q --disablerepo=* --enablerepo=epel install libyaml PyYAML cloud-init python-boto
rpm -Uvh http://www.bashton.com/downloads/centos-ami/RPMS/noarch/ec2-utils-0.2-1.5bashton1.el6.noarch.rpm

echo "   CHROOT - Installing API/AMI tools"
mkdir -p /opt/ec2/tools
curl -o /tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
unzip -qq /tmp/ec2-api-tools.zip -d /tmp
cp -r /tmp/ec2-api-tools-*/* /opt/ec2/tools
curl -o /tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
unzip -qq /tmp/ec2-ami-tools.zip -d /tmp
cp -r /tmp/ec2-ami-tools-*/* /opt/ec2/tools
rm -rf /tmp/ec2-a*
wget -O /opt/ec2/tools/bin/ec2-metadata http://s3.amazonaws.com/ec2metadata/ec2-metadata

# Create profile configs for java and aws
printf "export EC2_HOME=/opt/ec2/tools\nexport PATH=$PATH:$EC2_HOME/bin\n" >> /etc/profile.d/aws.sh
printf "export JAVA_HOME=/usr" >> /etc/profile.d/java.sh

cat > /root/mkgrub.sh <<'EOF'
#!/bin/bash
declare -a KERNELS
declare -a INITRDS
KERNELS=(/boot/vmlinuz*)

function do_header() {
printf "default=0\ntimeout=1\n" >> /boot/grub/menu.lst
}

function do_entry(){g
KERN=$1
VER=${KERN#/boot/vmlinuz-}
printf "\n\ntitle Scientific Linux ($VER)
 root (hd0,0)
 kernel $KERN ro root=/dev/xvde1 rootfstype=ext4 rd_NO_PLYMOUTH selinux=0 console=hvc0 \
 loglvl=all sync_console console_to_ring earlyprintk=xen nomodeset rd_NO_FSTAB \
 rd_NO_LUKS rd_NO_LVM rd_NO_MD rd_NO_DM LANG=en_US.UTF-8 \
 SYSFONT=latarcyrheb-sun16 KEYBOARDTYPE=pc KEYTABLE=us crashkernel=auto rhgb \
 max_loop=64 rdinfo biosdevname=0 rdloaddriver=xen_blkfront rdloaddriver=ext4\n \
 initrd /boot/initramfs-${VER}.img\n" >> /boot/grub/menu.lst
}

function do_close(){
cat /boot/grub/menu.lst
}

do_header
for ((j=0;j<${#KERNELS[@]};j++)); do
    do_entry ${KERNELS[$j]}
done
do_close
EOF

echo "   CHROOT - Creating /boot/grub/menu.lst"

bash /root/mkgrub.sh

echo "   CHROOT - Tweaking sshd config"
printf "UseDNS no\nPermitRootLogin without-password" >> /etc/ssh/sshd_config

cat > /etc/init.d/ec2-get-ssh <<'EOF'
#!/bin/bash
# chkconfig: 2345 95 20
# processname: ec2-get-ssh
# description: Capture AWS public key credentials for EC2 user
# Borrowed from http://www.idevelopment.info

# Source function library
. /etc/rc.d/init.d/functions

# Source networking configuration
[ -r /etc/sysconfig/network ] && . /etc/sysconfig/network

# Replace the following environment variables for your system
export PATH=:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Check that networking is configured
if [ "${NETWORKING}" = "no" ]; then
  echo "Networking is not configured."
  exit 1
fi

start() {
  if [ ! -d /root/.ssh ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
  fi
  # Retrieve public key from metadata server using HTTP
  curl -f http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key > /tmp/my-public-key
  if [ $? -eq 0 ]; then
    echo "EC2: Retrieve public key from metadata server using HTTP."
    cat /tmp/my-public-key >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    rm /tmp/my-public-key
  fi
}

stop() {
  echo "Nothing to do here"
}

restart() {
  stop
  start
}

# See how we were called.
case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart}"
    exit 1
esac

exit $?
EOF

chmod 755 /etc/init.d/ec2-get-ssh
chkconfig --level 34 ec2-get-ssh on

# This doesn't seem to be working as I would expect. More testing is needed.
echo "   CHROOT - Configuring cloud init"
mv /etc/cloud/cloud.cfg{,.orig}
cat > /etc/cloud/cloud.cfg <<'EOF'
ssh_pwauth:   0
cc_ready_cmd: ['/bin/true']
locale_configfile: /etc/sysconfig/i18n
mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']
mounts:
 - [ ephemeral0, /media/ephemeral0, auto, "defaults" ]
 - [ swap, none, swap, sw, "0", "0" ]
preserve_hostname: True
repo_upgrade: sl-security
ssh_deletekeys:   0
ssh_genkeytypes:  ~
ssh_svcname:      sshd
syslog_fix_perms: ~

cloud_init_modules:
 - bootcmd
 - resizefs
 - set_hostname
 - rsyslog
 - ssh

cloud_config_modules:
 - mounts
 - ssh-import-id
 - locale
 - set-passwords
 - timezone
 - puppet
 - runcmd

cloud_final_modules:
 - rightscale_userdata
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - keys-to-console
 - phone-home
 - final-message

# vim:syntax=yaml
EOF

sed -i -e 's,=enforcing,=disabled,' /etc/sysconfig/selinux

echo "   CHROOT - Updating kernel tools"
yum -e0 --enablerepo=sl-fastbugs -y install dracut dracut-kernel module-init-tools

echo "   CHROOT - Removing firmware"
rpm -e --nodeps *-firmware
yum -e0 -y -q install kernel-firmware

exit
STAGE2EOF
chmod 700 ${IMGLOC}/root/stage2.sh

}

function stage2_install() {
    
# Finally, chroot into the image
    echo "Entering chroot"
    chroot ${IMGLOC} su -c /root/stage2.sh
    echo "Exiting chroot"

}

function final_drive_prep() {

    echo "Setting drive parameters"
    tune2fs -c 0 ${DEVICE}1
    tune2fs -L / ${DEVICE}1
    echo "Creating swap volume"
    mkswap -L ebs-swap ${DEVICE}2
    echo "Cleaning up"
    yum -c ${IMGLOC}/etc/yum.conf --installroot=${IMGLOC} -y clean packages
    rm -rf ${IMGLOC}/root/.bash_history
    rm -rf ${IMGLOC}/var/cache/yum
    rm -rf ${IMGLOC}/var/lib/yum
    sync; sync; sync; sync

}

function unmount() {

    echo "Unmounting ${DEVICE} from ${IMGLOC}"
    for i in /{dev{/shm,/pts,},sys,proc,}
    do
        umount ${IMGLOC}${i}
    done
    echo "Unmounting ${IMGLOC}"
    umount ${IMGLOC}

}

if [ $EUID != 0 ]; then
    echo "*** ERROR - You must run this script as root"
    exit
fi

IMGLOC=
DEVICE=
while getopts :d:i:v: ARGS; do
    case $ARGS in
        d)
            if [ -L /sys/block/${OPTARG#/dev/} ]; then
                DEVICE=$OPTARG
            else
                echo "$OPTARG is an invalid device"
                exit
            fi
            ;;

        i)
            if [ -d $OPTARG ]; then
                CHECK=$( mount  | grep -E "$OPTARG " )
                if [ -n "$CHECK" ]; then
                    echo "Error $OPTARG is already mounted"
                    exit
                else
                    IMGLOC=$OPTARG
                fi
            else
                read -e -N 1 -p "$OPTARG doesn't exist. Would you like me to create it? (y/n)" CREATE
                if [[ "$CREATE" == "y|Y" ]]; then
                    mkdir -p $OPTARG || { echo "Could not create $OPTARG. Fix this and try again"; exit; }
                    IMGLOC=$OPTARG
                fi
            fi
            ;;

        *)
            usage
            exit
            ;;
    esac
done
main
