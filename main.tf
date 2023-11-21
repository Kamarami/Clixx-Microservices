#Create instance profile
#Create EC2 Launch Template
#Create ECS Instance ASG 
#Create Application Load Balancer
#Create target group for load balancer
#Configure load balancer to listen on port 80
#Attach ASG to target group
#Create ECS Cluster
#Create ECS Task definition
#Create ECS Service
#Obtain hosted zone id of load balancer from data source
#Route 53 record update
#Run task

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
  backend "s3"{
    bucket= "stackbuckstatemohamed1"
    key = "ecs-terraform.tfstate"
    region="us-east-1"
    dynamodb_table="statelock-tf"
  }
}
provider "aws" {
  region     = "us-east-1"
  }

/* provider "aws" {
  region = var.region
} */

#Configure public key
resource "aws_key_pair" "private_keypair" {
    key_name   = "private_keypair.pub"
    public_key = file(var.PATH_TO_PUBLIC_KEY)
}

data "aws_iam_role" "instance_role" {
  name = "ecsInstanceRole"
}

#Create instance profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = data.aws_iam_role.instance_role.name
}

#Create EC2 Launch Template
resource "aws_launch_template" "ecs-lt" {
  name                   = "ecs-lt"
  image_id               = data.aws_ami.ecs-optimized.id
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.private_keypair.key_name
  vpc_security_group_ids = data.aws_security_groups.lt-sg.ids
  user_data              = base64encode("#!/bin/bash\necho ECS_CLUSTER=clixx-ecs >> /etc/ecs/ecs.config") //attach cluster to instance launch template
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 100
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name       = "clixx-ecs-inst"
      OwnerEmail = "mohamedxkamara@gmail.com"
      Backup     = "Yes"
      Schedule   = "A"
      StackTeam  = "stackcloud9"
    }
  }

  depends_on = [aws_ecs_cluster.clixx-ecs]
  lifecycle {
    create_before_destroy = true
  }
}

#Create ECS Instance ASG 
resource "aws_autoscaling_group" "ecs-asg" {
    name                      = "ecs-asg"
    vpc_zone_identifier       = ["subnet-e7ed77b8"]
    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 3
    health_check_grace_period = 30
    health_check_type         = "EC2"

    launch_template {
    id      = aws_launch_template.ecs-lt.id
    version = "$Latest"
  }
}

#Create Application Load Balancer
resource "aws_alb" "ecs-alb" {
  name            = "ecs-alb"
  load_balancer_type = "application"
  security_groups = ["sg-0c7e9e0f6c7477c7e"]
  subnets            = [
    "subnet-e7ed77b8",
    "subnet-2c2e0761",
    "subnet-979f32a6",
    "subnet-9625bbf0",
    "subnet-37a4c016",
    "subnet-6102516f"
  ]
}

#Create target group for load balancer
resource "aws_lb_target_group" "ecs-tg" {
  name        = "ecs-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-c15cf6bc"
  
  health_check {
    path   = "/"
    matcher = "403,200"
  }
}

#Configure load balancer to listen on port 80
resource "aws_lb_listener" "ecs-alb-listener" {
  load_balancer_arn = aws_alb.ecs-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.ecs-tg.id
    type             = "forward"
  }
}

#Attach ASG to target group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ecs-asg.name
  alb_target_group_arn   = aws_lb_target_group.ecs-tg.arn
}

#Create ECS Cluster
resource "aws_ecs_cluster" "clixx-ecs" {
  name = "clixx-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

#Create ECS Task definition
resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                   = "ecs-task-definition"
  network_mode             = "bridge"
  task_role_arn            = "arn:aws:iam::597529641504:role/ecsTaskExecutionRole"
  execution_role_arn       = "arn:aws:iam::597529641504:role/ecsTaskExecutionRole"
  requires_compatibilities = ["EC2"]
  cpu                      = 512
  memory                   = 900

  container_definitions = <<DEFINITION
[
  {
    "image": "597529641504.dkr.ecr.us-east-1.amazonaws.com/clixx-repository:clixx-image-1.0.59",
    "cpu": 10,
    "memory": 300,
    "essential": true,
    "name": "container",
    "networkMode": "bridge",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 8080 
      }
    ]
  }
]
DEFINITION
}

#Create ECS Service
resource "aws_ecs_service" "clixx-service" {
  name            = "clixx-service"
  cluster         = "${aws_ecs_cluster.clixx-ecs.id}"
  task_definition = "${aws_ecs_task_definition.ecs-task-definition.arn}"
  desired_count   = 2
  iam_role        = data.instance_role.id
  launch_type     = "EC2"

  ordered_placement_strategy {
    type = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.ecs-tg.id}"
    container_name   = "container"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  depends_on = [ aws_ecs_task_definition.ecs-task-definition, aws_lb_target_group.ecs-tg]
  //depends_on = [aws_lb_listener.ecs-alb-listener, aws_ecs_task_definition.ecs-task-definition, aws_lb_target_group.ecs-tg]
}

#Obtain hosted zone id of load balancer from data source
data "aws_lb_hosted_zone_id" "main" {}

#Route 53 record update
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "ecs.dev-clixx-mohamed.com"
  type    = "A"

  alias {
    name                    = aws_alb.ecs-alb.dns_name
    zone_id                 = aws_alb.ecs-alb.zone_id
    evaluate_target_health  = true
  }
}

/* #Run task
resource "aws_ecs_task_set" "clixx-task" {
  service         = aws_ecs_service.clixx-service.id
  cluster         = aws_ecs_cluster.clixx-ecs.id
  task_definition = aws_ecs_task_definition.ecs-task-definition.arn

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-tg.arn
    container_name   = "clixx-repository"
    container_port   = 80
  }
} */


output "load_balancer_ip" {
  value = aws_alb.ecs-alb.dns_name
}
