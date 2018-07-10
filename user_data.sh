#!/bin/sh

# attach EBS filesystem

sleep 10

DEVICE=/dev/$(lsblk -n | awk '$NF != "/" {print $1}' | grep -v xvda)
FS_TYPE=$(file -s $DEVICE | awk '{print $2}')
MOUNT_POINT=/storage

# If no FS, then this output contains "data"
if [ "$FS_TYPE" = "data" ]
then
    echo "Creating file system on $DEVICE"
    mkfs -t ext4 $DEVICE
fi

mkdir $MOUNT_POINT

echo "" >> /etc/fstab
echo "$DEVICE		/storage	ext4	defaults,nofail 1 2" >> /etc/fstab 

mount -a 


# CloudWatchMonitoringScripts

sudo yum install -y perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA.x86_64 zip unzip wget 

mkdir /opt

wget https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -P /opt

cd /opt
unzip CloudWatchMonitoringScripts-1.2.2.zip
rm CloudWatchMonitoringScripts-1.2.2.zip


echo '*/5 * * * * root perl /opt/aws-scripts-mon/mon-put-instance-data.pl --mem-util --disk-space-util --disk-path=/ --disk-path=/storage >> /var/log/cwpump.log 2>&1' > /etc/cron.d/cwpump
