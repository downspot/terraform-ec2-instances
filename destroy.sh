#!/bin/sh 


if (( $# != 1 )); then
    echo "Usage: ${0} <preprod|prod>"
    exit 1
fi

    
terraform workspace list | grep ds-operations-${1} > /dev/null 

if (( $? != 0 )); then
    terraform workspace new ds-operations-${1}
fi

terraform workspace select ds-operations-${1}
terraform destroy -var-file=variables.tfvars

