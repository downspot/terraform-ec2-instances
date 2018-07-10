## ec2-instance 

- creates EC2 instance(s)
- creates volumes of selected sizes and mounts to /storage
- applies reboot cloudwatch for hung states
- create cloudwatch for /storage /root and CPU utilization (must use Lambda function)

Edit appropriate `*.tfvars` file.


Deploy with:

`./deploy.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`

Destroy with:

`./destory.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`

Show with:

`./show.sh <app name> <dev|preprod|prod> <us-east-1|us-west-2>`
