data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default=true
}

resource "aws_instance" "tester" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ module.security-group.security_group_id ]
  subnet_id= module.tester_vpc.public_subnets[0]

  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_security_group" "tester" {
  name         = "tester"
  description  = "security group for learning terraform that allows http and https"
  vpc_id       = data.aws_vpc.default.id
}


module "security-group" {
  source       = "terraform-aws-modules/security-group/aws"
  version      = "5.1.0"
  vpc_id       = module.tester_vpc.vpc_id
  name         ="security_groups_using_modules"
  
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "tester_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "tester-alb"

  load_balancer_type = "application"

  vpc_id             = module.tester_vpc.vpc_id
  subnets            = module.tester_vpc.public_subnets
  security_groups    = [module.security-group.security_group_id]

  access_logs = {
    bucket = "my-alb-logs"
  }

  target_groups = [
    {
      name_prefix      = "tester-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = {
        my_target = {
          target_id = aws_instance.tester.id
          port = 80
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}