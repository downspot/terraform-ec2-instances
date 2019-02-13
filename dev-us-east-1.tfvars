instance_type = "t2.medium"
security_group = "ds-ops-dev"
key_name = "DS-OPS"
iam_instance_profile = "DS-OPS"
root_vol_size = "50"
storage_vol_size = "50"
count = "3"
prd_code = "PRD349"
vpc = "DATASCIENCES-DEV-EAST"
key_path = "/home/ec2-user/.ssh/DS-OPS.pem" 
termination_protection = "false"
