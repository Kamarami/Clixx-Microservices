variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default     = "10.1.0.0/16"
}
variable "cidr_subnet" {
  description = "CIDR block for the subnet"
  default     = "10.1.0.0/24"
}

variable "environment_tag" {
  description = "Environment tag"
  default     = "Learn"
}

variable "region"{
  description = "The region Terraform deploys your instance"
  default     = "us-east-1"
}

variable "vpc_id"{
    default="vpc-0eca7b97f699bd94f"
}

variable "subnets" {
  type = list(string)
  default=[
    "subnet-043e81b983d617a8f",
    "subnet-2c2e0761",
   ]
}

variable "ami_name" {
  default = "ami-stack-51"
}

variable "ami_id" {
  default = "ami-0ac7415dd546fb485"
}

variable "ecs_ami" {
  default = "ami-stack-51"
}

variable "PATH_TO_PRIVATE_KEY" {
  default = "private_keypair"
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "private_keypair.pub"
}