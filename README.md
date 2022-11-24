# Provision EKS
This tf is able to create EKS automatically with sufficient addons, including ebs csi, oidc, metrics server and accessing s3.
You can research the main.tf by your interest.
## Prepare ENV
* Prepare AWS credentials in '~/.aws'
* Install terraform by yourself

## Customize configuration
* Specify EKS name in 'variables.tf'
* Specify WorkerNode configuration in 'main.tf'

## Deploy
```
terraform init
terraform apply
```

## Destroy resource
```
terraform destroy
```
