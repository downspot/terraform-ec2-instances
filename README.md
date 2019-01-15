## ec2-instance 



Edit or create appropriate `*.tfvars` file formatting as follows:

```
instance_type = "t2.medium"
security_group = "ds-ops-test"
key_name = "DS-OPS"
iam_instance_profile = "DS-OPS"
root_vol_size = "50"
storage_vol_size = "50"
count = "2"
prd_code = "PRD349"
vpc = "DATASCIENCES-DEV-EAST"
key_path = "/home/ec2-user/.ssh/DS-OPS.pem" 
```


File name formatting corresponds to environment, adjust accordingly:

dev-us-east-1.tfvars 



Deploy with:

`./deploy.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`

Destroy with:

`./destory.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`

Show with:

`./show.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`
