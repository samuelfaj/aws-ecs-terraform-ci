# This resource block creates an AWS Security Group. 
# Security groups act as a virtual firewall for your instance to control inbound and outbound traffic.
resource "aws_security_group" "ecs_tasks" {
  # The name of the security group.
  name        = "ecs_tasks_sg"
  # Description for the security group.
  description = "Allow inbound traffic on all ports"

  # Ingress rules define what kind of traffic is allowed into the instances attached to this security group.
  ingress {
    # 'from_port' and 'to_port' both being 0 means all ports are allowed.
    from_port   = 0
    to_port     = 0
    # 'protocol' being 'ALL' means all protocols are allowed.
    protocol    = "ALL"
    # 'cidr_blocks' being ["0.0.0.0/0"] means the traffic can originate from anywhere.
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules define what kind of traffic is allowed out from the instances attached to this security group.
  egress {
    # Similar to the ingress rule above, all traffic is allowed to go out to any IP on any protocol and port.
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# This resource block creates an AWS EC2 instance. EC2 instances are virtual servers in Amazon's Elastic Compute Cloud (EC2) for running applications.
resource "aws_instance" "ecs_instance" {
  # The ID of the AMI, or Amazon Machine Image, which provides the information required to launch the instance.
  # You will need to replace this with the latest Amazon ECS-optimized Amazon Linux 2 AMI.
  ami           = "ami-0ebb9b1c37ef501ab"
  
  # The instance type. This defines the hardware of the host computer for the instance.
  instance_type = "t3.small"
  
  # The name of the key pair to use for the instance.
  key_name      = "ttl-servers"

  # An instance profile is a way to grant the necessary permissions to the EC2 instance that your ECS tasks run on.
  # We're referring to the name of the IAM instance profile that we created earlier.
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  # User data is used to configure the instance upon launch. 
  # Here, we're providing a shell script (ecs_instance.sh) as a template file, which sets the ECS cluster name.
  user_data = templatefile("${path.module}/assets/ecs_instance.sh", { cluster_name = aws_ecs_cluster.ttl_worker.name })

  # A list of security group IDs to assign to the instance. Here we're using the ID of the security group we created earlier.
  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]

  # Tags are used to assign metadata to AWS resources. Here, we're assigning a Name tag to the instance.
  tags = {
    Name = "ECS Instance"
  }
}