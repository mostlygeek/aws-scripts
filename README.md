**aws_sl62_ebs_ami.sh** : simple script for creating an AMI image from scratch  
* assumes you are running this from an existing AMI in the AWS cloud  
* only creates SL 6.2 AMI's  
* assumes that you have already presented an ebs volue to the instance  
* currently set for a 20GB ebs volume  
* creates a seperate root (18gb) and swap (2gb) partition  
* package loadout is somewhat tailored to *my* current needs.  

YMMV.  


