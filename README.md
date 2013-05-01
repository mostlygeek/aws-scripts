### aws\_sl62\_ebs\_ami.sh

A simple script for creating an AMI image from scratch
* assumes you are running this from an existing AMI in the AWS cloud  
* only creates SL 6.2/3 AMI's  
* assumes that you have already presented an ebs volume to the instance  
* currently set for a 20GB ebs volume  
* creates a separate root (18gb) and swap (2gb) partition  
* package loadout is somewhat tailored to *my* current needs.  
* cloud-init script remains a work in progress

### Steps for use

1. Obtain a Linux based AMI in amazon (distro shouldn't matter, but amazon makes a nice one)
2. Boot the AMI
3. Present a new 20 GB EBS volume to the host. Make a note of the device presented to the host OS. It will be needed when running the script.
4. Obtain the script from https://raw.github.com/ckolos/aws-scripts/master/aws_sl62_ebs_ami.sh
5. Run the script as shown below 

### Script Usage

      This script is invoked as: 
      
      aws_sl62_ebs_ami.sh -d <device> -i <directory for image> -v <version>
      
      Where:
       -d  = Device to be used in /dev/<devicename> format (ex. /dev/sdb)

       -h  = Help (this message)

       -i  = Directory where the specified device's first partition will be mounted (ex. /mnt/image).
             If this directory doesn't exist, the script will prompt you to create it.

       -v  = Version to be installed (6.[2|3] are the only valid options at this time)

       A 20 GiB EBS volume will be partitioned as below.

        /dev/<device>1 = /    (18 GB)
        /dev/<device>2 = swap (2  GB)
        / will be formatted as ext4
