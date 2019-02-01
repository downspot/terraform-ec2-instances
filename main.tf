variable "prd_code" {}
variable "inventory_code" {}
variable "aws_region" {}
variable "instance_type" {}
variable "key_name" {}
variable "security_group" {}
variable "iam_instance_profile" {}
variable "tag_env" {}
variable "tag_name" {}
variable "count" {}
variable "root_vol_size" {}
variable "storage_vol_size" {}
variable "key_path" {}
variable "vpc" {}
variable "termination_protection" {}

variable "vpc_name_to_id" {
  type    = "map"

  default = {
    "DATASCIENCES-DEV-EAST" = "vpc-1bab5a7f"
    "DATASCIENCES-EAST" = "vpc-4c160f29"
    "DATASCIENCES-DEV-WEST" = "vpc-c70a7ca2"
    "DATASCIENCES-WEST" = "vpc-422f4b27"
  }
}

variable "vpc_id_to_name" {
  type    = "map"

  default = {
    "vpc-1bab5a7f" = "PRIV-*-DATASCIENCES-DEV-*"
    "vpc-4c160f29" = "PRIV-*-DATASCIENCES-*"
    "vpc-c70a7ca2" = "PRIV-*-DATASCIENCES-DEV-*"
    "vpc-422f4b27" = "PRIV-*-DATASCIENCES-*"
  }
}



locals {
  vpc_name = "${lookup(var.vpc_name_to_id, var.vpc)}"
}



provider "aws" {
  region = "${var.aws_region}"
}



terraform {
  backend "s3" {}
}



data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = "true"

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = "${lookup(var.vpc_name_to_id, var.vpc)}"

  filter {
    name = "tag:Name"

    values = [
      "${lookup(var.vpc_id_to_name, local.vpc_name)}",
    ]
  }
}

data "aws_security_group" "name" {
  vpc_id = "${lookup(var.vpc_name_to_id, var.vpc)}"

  filter {
    name = "tag:Name"

    values = [
      "${var.security_group}",
    ]
  }

  depends_on = ["aws_security_group.allow_all"]

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

data "template_file" "user_data" {
  template = "${file("user_data.sh")}"
}



resource "aws_security_group" "allow_all" {

  name        = "${var.security_group}"
  description = "${var.security_group}"
  vpc_id      = "${lookup(var.vpc_name_to_id, var.vpc)}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name          = "${var.security_group}"
    ProductCode   = "${var.prd_code}"
    InventoryCode = "${var.inventory_code}"
    Environment   = "${var.tag_env}"
  }

  lifecycle {
    create_before_destroy = "true"
  }

}

resource "null_resource" "ds-operations" {
    count = "${var.count}"

provisioner "remote-exec" {
    when   = "destroy"
    inline = [
      "sudo umount /mnt/store01"
    ]

connection {
     user       = "ec2-user"
     host       = "${element(aws_instance.ds-operations.*.private_ip, count.index)}"
     private_key = "${file("${var.key_path}")}"
    }
  }
}

resource "aws_instance" "ds-operations" {
  ami 			  = "${data.aws_ami.amazon_linux.id}"
  instance_type           = "${var.instance_type}"
  subnet_id               = "${element(data.aws_subnet_ids.private.ids, count.index)}"
  key_name                = "${var.key_name}"
  vpc_security_group_ids  = ["${data.aws_security_group.name.id}"]
  iam_instance_profile    = "${var.iam_instance_profile}"
  user_data               = "${data.template_file.user_data.rendered}"
  count 		  = "${var.count}"
  disable_api_termination = "${var.termination_protection}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.root_vol_size}"
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name 	  = "/dev/xvdf"
    volume_size 	  = "${var.storage_vol_size}"
    volume_type 	  = "gp2"
    delete_on_termination = "true"
  }

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
    alarm_actions       = ["arn:aws:automate:${var.aws_region}:ec2:recover"]
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
    threshold 		= "80.0"
    alarm_description 	= "Root filesystem over 80%"
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
    threshold           = "80.0"
    alarm_description   = "Storage filesystem over 80%"
    count               = "${var.count}"
    alarm_actions      	= ["${aws_sns_topic.health_updates.arn}"]
    ok_actions         	= ["${aws_sns_topic.health_updates.arn}"]
      dimensions {
         Filesystem = "/dev/xvdf"
         InstanceId = "${element(aws_instance.ds-operations.*.id, count.index)}"
         MountPath = "/mnt/store01"
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
