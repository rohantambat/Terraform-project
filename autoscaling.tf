terraform {
  required_providers {
    aws = "~> 3.70"
  }

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "TerraformVPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id

  // Define your security group rules here
  // For example, allow incoming HTTP and SSH traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // You can add more rules as needed
}


resource "aws_ec2_instance" "web" {
  count = 2
  ami = "ami-08d61c4a8943c6593"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
}

resource "aws_autoscaling_group" "web" {
  name = "web-asg"
  min_size = 2
  max_size = 4
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.web.name
  target_group_arns = [aws_lb.alb.target_group_arn]
}

resource "aws_launch_configuration" "web" {
  image_id = "ami-08d61c4a8943c6593"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data = <<EOF
#!/bin/bash

echo "Hello, world!" > /var/www/html/index.html
EOF
}

resource "aws_lb" "alb" {
  name = "web-alb"
  subnets = [aws_subnet.public.id]
  security_groups = [aws_security_group.alb.id]

  listener {
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.web.arn
    }
  }
}

resource "aws_lb_target_group" "web" {
  name = "web-alb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  health_check {
    protocol = "HTTP"
    matcher = "200"
    path = "/"
  }
}

resource "aws_cloudwatch_metric_alarm" "default" {
    name = "my-cloudwatch-alarm"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    threshold = 80
    stat = "Average"
    period = 60
    evaluation_periods = 2
    alarm_actions = [aws_autoscaling_group.default.arn]
  }

  resource "aws_sns_topic" "default" {
    name = "my-sns-topic"
  }

  resource "aws_sns_topic_subscription" "default" {
    topic_arn = aws_sns_topic.default.arn
    endpoint = "your_email_address@example.com"
    protocol = "email"
  }
