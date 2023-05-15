# Instance
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs_tasks_sg"
  description = "Allow inbound traffic on all ports"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ecs_instance" {
  ami           = "ami-0ebb9b1c37ef501ab" # Replace with the latest Amazon ECS-optimized Amazon Linux 2 AMI
  instance_type = "t3.small"
  key_name      = "ttl-servers"

  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = templatefile("${path.module}/assets/ecs_instance.sh", { cluster_name = aws_ecs_cluster.ttl_worker.name })

  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]

  tags = {
    Name = "ECS Instance"
  }
}