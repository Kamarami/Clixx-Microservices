locals {
  /* current_account_id = data.aws_caller_identity.current.account_id
  launch_template_name = local.current_account_id == local.clixx_creds.auto_account_number ? "multi-az-clixx-auto" : "unknown" */

  wp_creds = jsondecode(
    data.aws_secretsmanager_secret_version.wp_creds.secret_string
  )

  aws_provider_config = {
    region     = local.wp_creds.AWS_REGION
    access_key = local.wp_creds.AWS_ACCESS_KEY
    secret_key = local.wp_creds.AWS_SECRET_KEY
  }
}

data "aws_secretsmanager_secret_version" "wp_creds" {
#secret name
 secret_id = "clixxcreds"
}

data "aws_vpc" "selected" {
  filter {
    name    = "tag:Name"
    values  = ["clixxvpc"]
  }
}
data "aws_iam_role" "instance_role" {
  name = "ecsInstanceRole"
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

data "aws_security_groups" "lt-sg" {
  filter {
    name    = "group-name"
    values  = ["lt-sg"]
  }
  filter {
    name    = "vpc-id"
    values  = ["data.aws_vpc.selected.id"]
  }
}
#Datasoure to retrieve image ID
data "aws_ami" "ecs-optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

data "template_file" "bootstrap"{
  template      = file(format("%s/scripts/lt-bootstrap", path.module))
}

#Obtain zone ID via datasource
data "aws_route53_zone" "selected" {
  name  = "dev-clixx-mohamed.com"
}