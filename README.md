### aws\_sl62\_ebs\_ami.sh

A simple script for creating an AMI image from scratch
* assumes you are running this from an existing AMI in the AWS cloud  
* only creates SL 6.2/3 AMI's  
* assumes that you have already presented an ebs volume to the instance  
* package loadout is somewhat tailored to *my* current needs.  
* cloud-init script remains a work in progress

### Steps for use

1. Obtain a Linux based AMI in AWS (the distro shouldn't matter, but amazon makes a nice one)
2. Boot the AMI
3. Present a new EBS volume to the host. Make a note of the device presented to the host OS. It will be needed when running the script.
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

      All space on the presented volume will be used!
      
      / will be formatted as ext4

### Creating the AMI
1. Once the script has completed, take a snapshot of the presented volume
2. After the snapshot has been completed, in the AWS Snapshot management web interface, right click on the snapshot and select "Create image from snapshot"
3. Modify the following values:
  1. Name: whatever you wish
  2. Architechture: x86\_64
  3. Kernel ID: Up to you, but if using the ebs\_ami script, be sure to select an pv-grub/hd00 image (currently aki-b4aa75dd in us-east-1)
  4. Description: again, your call
  5. Root Device Name: This is critical. If using the ebs\_ami script, change this FROM /dev/sda1 TO /dev/sda (i.e. remove the '1')
  6. Ramdisk ID: can be left at default
  7. If ephemeral storage is wanted, click on 'Instance Store Volumes' in the 'Block Device Mapping' and select however many instances you wish.
4. Click 'Yes, Create'

