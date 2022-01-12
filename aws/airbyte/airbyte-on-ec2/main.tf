resource "aws_ebs_volume" "airbyte" {
  availability_zone = "us-east-2a"
  size              = var.volume_size

  tags = {
    Name        = "airbyte"
    managed-by  = "terraform"
    environment = var.environment
  }
}

resource "aws_launch_template" "airbyte" {
  name = "airbyte"

  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "airbyte"
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  user_data = base64encode(templatefile("${path.module}/airbyte-install.sh",
    {
      region     = data.aws_region.current.name
      linux_type = var.linux_type
    }
  ))
}

resource "aws_autoscaling_group" "airbyte" {
  name             = "airbyte-asg"
  max_size         = var.max_capacity
  min_size         = var.min_capacity
  desired_capacity = var.desired_capacity

  health_check_grace_period = 300
  health_check_type         = "EC2"

  vpc_zone_identifier = [var.subnet_id]

  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupMinSize", "GroupMaxSize", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupStandbyCapacity", "GroupTerminatingCapacity", "GroupTerminatingInstances", "GroupTotalCapacity", "GroupTotalInstances"]

  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.airbyte.id
    version = "$Latest"
  }
}

resource "aws_security_group" "sg" {
  name   = "airbyte-instance"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name         = "airbyte-instance"
    "managed-by" = "terraform"
  }
}