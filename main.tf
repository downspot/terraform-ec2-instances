variable "prd_code" {}
variable "inventory_code" {}
variable "aws_region" {}
variable "instance_type" {}
variable "key_name" {}
variable "vpc_security_group_ids" {}
variable "subnet_id" {}
variable "iam_instance_profile" {}
variable "tag_env" {}
variable "tag_name" {}
variable "count" {}
variable "vol_size" {}
variable "availability_zone" {}
variable "key_path" {}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = "${var.aws_region}"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "terraform_remote_state" "network" {
  backend       = "s3"
  workspace     = "${terraform.workspace}"

  config {
    bucket      = "ds-operations-terraform-${var.aws_region}"
    key         = "terraform.tfstate"
    region      = "${var.aws_region}"
  }
}

terraform {
  backend "s3" {}
}

data "template_file" "user_data" {
  template = "${file("user_data.sh")}"
}

resource "aws_ebs_volume" "ds-operations" {
    availability_zone = "${var.availability_zone}"
    size 	      = "${var.vol_size}"
    type 	      = "gp2"
    count 	      = "${var.count}"

  tags {
    Name 	  = "${var.tag_name}"
    ProductCode   = "${var.prd_code}"
    InventoryCode = "${var.inventory_code}"
    Environment   = "${var.tag_env}"
  }
}

resource "aws_volume_attachment" "ds-operations" {
    device_name = "/dev/xvdf"
    count 	= "${var.count}"
    volume_id 	= "${element(aws_ebs_volume.ds-operations.*.id, count.index)}"
    instance_id = "${element(aws_instance.ds-operations.*.id, count.index)}"
}

resource "aws_instance" "ds-operations" {
  ami 			 = "${data.aws_ami.amazon_linux.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  iam_instance_profile   = "${var.iam_instance_profile}"
  user_data              = "${data.template_file.user_data.rendered}"
  count 		 = "${var.count}"
  availability_zone	 = "${var.availability_zone}"

  tags {
    Name          = "${var.tag_name}-${var.tag_env}"
    ProductCode   = "${var.prd_code}"
    InventoryCode = "${var.inventory_code}"
    Environment   = "${var.tag_env}"
  }

  volume_tags {
    Name          = "${var.tag_name}"
    ProductCode   = "${var.prd_code}"
    InventoryCode = "${var.inventory_code}"
    Environment   = "${var.tag_env}"
  }
}

resource "null_resource" "ds-operations" {
    count = "${var.count}"

provisioner "remote-exec" {
    when   = "destroy"
    inline = [
      "sudo umount /storage"
    ]

connection {
     user 	 = "ec2-user"
     host 	 = "${element(aws_instance.ds-operations.*.private_ip, count.index)}"
     private_key = "${file("${var.key_path}")}"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "recovery" {
    alarm_name          = "${element(aws_instance.ds-operations.*.id, count.index)}-recovery"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods  = "2"
    metric_name         = "StatusCheckFailed_System"
    namespace           = "AWS/EC2"
    period              = "60"
    statistic           = "Maximum"
    threshold           = "1.0"
    alarm_description   = "EC2 Recovery Alarm"
    count 	 	= "${var.count}"
    alarm_actions       = ["arn:aws:automate:us-east-1:ec2:recover"]
      dimensions {
        InstanceId      = "${element(aws_instance.ds-operations.*.id, count.index)}"
    }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
    alarm_name          = "${element(aws_instance.ds-operations.*.id, count.index)}-cpu_utilization"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods  = "1"
    metric_name 	= "CPUUtilization"
    namespace 		= "AWS/EC2"
    period 		= "300"
    statistic 		= "Average"
    threshold 		= "80.0"
    alarm_description 	= "CPUUtilization over 80%"
    count 	 	= "${var.count}"
    alarm_actions      	= ["${aws_sns_topic.health_updates.arn}"]
    ok_actions         	= ["${aws_sns_topic.health_updates.arn}"]
      dimensions {
         InstanceId 	= "${element(aws_instance.ds-operations.*.id, count.index)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_usage_root" {
    alarm_name          = "${element(aws_instance.ds-operations.*.id, count.index)}-disk_usage_root"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = "1"
    metric_name 	= "DiskSpaceUtilization"
    namespace           = "System/Linux"
    period 		= "300"
    statistic 		= "Average"
    threshold 		= "70.0"
    alarm_description 	= "Root filesystem over 70%"
    count 	 	= "${var.count}"
    alarm_actions 	= ["${aws_sns_topic.health_updates.arn}"]
    ok_actions 		= ["${aws_sns_topic.health_updates.arn}"]
      dimensions {
         Filesystem = "/dev/xvda1"
         InstanceId = "${element(aws_instance.ds-operations.*.id, count.index)}"
         MountPath = "/"
    }
}

resource "aws_cloudwatch_metric_alarm" "disk_usage_storage" {
    alarm_name          = "${element(aws_instance.ds-operations.*.id, count.index)}-disk_usage_storage"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = "1"
    metric_name         = "DiskSpaceUtilization"
    namespace           = "System/Linux"
    period              = "300"
    statistic           = "Average"
    threshold           = "70.0"
    alarm_description   = "Storage filesystem over 70%"
    count               = "${var.count}"
    alarm_actions      	= ["${aws_sns_topic.health_updates.arn}"]
    ok_actions         	= ["${aws_sns_topic.health_updates.arn}"]
      dimensions {
         Filesystem = "/dev/xvdf"
         InstanceId = "${element(aws_instance.ds-operations.*.id, count.index)}"
         MountPath = "/storage"
    }
}

resource "aws_sns_topic" "health_updates" {
    name = "${var.tag_name}-${var.tag_env}"
}

resource "aws_sns_topic_subscription" "health_updates_sns" {
    topic_arn                 = "${aws_sns_topic.health_updates.arn}"
    protocol                  = "lambda"
    endpoint                  = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:DsOpsSlackNotifications"
    raw_message_delivery      = "false"
}

resource "aws_lambda_permission" "with_sns" {
    statement_id 	= "${var.tag_name}-${var.tag_env}"
    action 		= "lambda:InvokeFunction"
    function_name 	= "DsOpsSlackNotifications"
    principal 		= "sns.amazonaws.com"
    source_arn 		= "${aws_sns_topic.health_updates.arn}"
}

output "image_id" {
    value = "${data.aws_ami.amazon_linux.id}"
}

output "instance_id" {
     value = ["${aws_instance.ds-operations.*.id}"]
}

output "private_ip" {
     value = ["${aws_instance.ds-operations.*.private_ip}"]
}
