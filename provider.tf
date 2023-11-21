provider "aws" {
  region     = "us-east-1"
  access_key = local.wp_creds.AWS_ACCESS_KEY
  secret_key = local.wp_creds.AWS_SECRET_KEY
  alias      = "cred_provider"
  config     = local.aws_provider_config
  assume_role {
    role_arn = "arn:aws:iam::667844852354:role/Engineer"
  }
}

