#!/bin/sh

###################################################################################################################################################

# attach EBS filesystem

sleep 20

DEVICE=/dev/$(lsblk -n | awk '$NF != "/" {print $1}' | grep -v xvda)
FS_TYPE=$(file -s $DEVICE | awk '{print $2}')
MOUNT_POINT=/mnt/data

# If no FS, then this output contains "data"
if [ "$FS_TYPE" = "data" ]
then
    echo "Creating file system on $DEVICE"
    mkfs -t xfs $DEVICE
    mkdir $MOUNT_POINT
    echo "" >> /etc/fstab
    echo "$DEVICE		/mnt/data		xfs	rw,noatime 1 1" >> /etc/fstab 
    mount -va 
fi


# Nagios

rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y nagios-plugins-all nrpe


# CloudWatchMonitoringScripts

yum install -y perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA.x86_64 zip unzip wget

mkdir /opt

wget https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -P /opt

cd /opt
unzip CloudWatchMonitoringScripts-1.2.2.zip
rm CloudWatchMonitoringScripts-1.2.2.zip

echo '*/5 * * * * root perl /opt/aws-scripts-mon/mon-put-instance-data.pl --mem-util --disk-space-util --disk-path=/ --disk-path=/mnt/data >> /var/log/cwpump.log 2>&1' > /etc/cron.d/cwpump


# script for setting hostname

cat <<'EOF' >> /root/set_hostname.sh 
#!/bin/sh 

sudo dig +short -x `GET http://169.254.169.254/latest/meta-data/local-ipv4` @dns0000.ash1.datasciences.tmcs | sed s'/.$//' | sudo xargs hostnamectl set-hostname
sudo sed -i '/hostname/d' /etc/cloud/cloud.cfg
EOF

###################################################################################################################################################
