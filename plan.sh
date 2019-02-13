#!/bin/sh

if (( $# != 3 )); then
    echo "Usage: ${0} <app name> <dev|preprod|prod> <us-east-1|us-west-2>"
    exit 1
fi

terraform init \
     -backend-config "bucket=ds-operations-terraform-${3}" \
     -backend-config "region=${3}" \
     -backend-config "key=terraform.tfstate"
terraform workspace list | grep ${1}-${2}-${3} > /dev/null 

if (( $? != 0 )); then
    terraform workspace new ${1}-${2}-${3}
fi

terraform workspace select ${1}-${2}-${3}
terraform plan -var-file=${2}-${3}.tfvars -var aws_region=${3} -var tag_name=${1} -var tag_env=${2} -var inventory_code=${1}
