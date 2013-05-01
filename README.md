**aws_sl62_ebs_ami.sh** : simple script for creating an AMI image from scratch  
* assumes you are running this from an existing AMI in the AWS cloud  
* only creates SL 6.2/3 AMI's  
* assumes that you have already presented an ebs volume to the instance  
* currently set for a 20GB ebs volume  
* creates a separate root (18gb) and swap (2gb) partition  
* package loadout is somewhat tailored to *my* current needs.  
* cloud-init script remains a work in progress

## Usage

* boot an Amazon Linux AMI (or any linux AMI really) 
    * add an extra 20GB EBS volume (going to snapshot this later)
    * usually comes out as `/dev/sdd`, but make a note of what device it is mapped to
    * the linux AMI makes `/dev/sdd` as a symlink for the real device, `/dev/xvdd`. You want to use `/dev/xvdd`.
* get the script onto the server: `curl -O https://raw.github.com/mostlygeek/aws-scripts/master/aws_sl62_ebs_ami.sh`
* run it: `./awsL-sl62_ebs_ami -d /dev/xvdd -i /mnt/image -v 6.3`
* when it's completed, the EBS volume can be snapshotted and used to boot a new AMI

