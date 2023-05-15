## AWS ECS: Managing Multiple Containers in an Easy Way.

At some point, you may have encountered the following question: “How can I manage and update multiple services running simultaneously on my server?” The answer to this challenge is, in fact, simpler than it seems. In this post, we will explore an efficient and elegant way to solve this problem. We will discuss creating an individual container for each service, using AWS ECS to manage them effectively, and finally, implementing Gitlab CI to ensure consistent and effortless updates of these containers. Continue reading and discover how to make the management of your server a more peaceful and efficient process!

### Chapter 1: Terraform

Terraform is a tool that allows you to write Infrastructure as Code (IaC), making it easier to manage and automate IT resources.

We start the configuration by creating a file called main.tf. This file will be the foundation of our infrastructure.

```sh
provider "aws" {
    region = "us-east-1"
}
```

This code specifies that we will be using AWS as our infrastructure provider, specifically in the us-east-1 region.

Next, we create the aws-ecs.tf file. This file will be responsible for creating the AWS ECS cluster and defining its permissions:

```sh
# This resource block creates an Amazon Elastic Container Service (ECS) cluster.
# An ECS cluster is a logical grouping of tasks or services. In this case, the 
# cluster is named "devninja_worker".
resource "aws_ecs_cluster" "devninja_worker" {
  name = "devninja_worker"
}

# Here we're creating an AWS IAM (Identity and Access Management) role.
# IAM roles are a secure way to grant permissions to entities that you trust.
# This IAM role is named "ecs_role".
resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"

  # The 'assume_role_policy' is a policy that grants an entity permission to assume the role.
  # In this case, it allows the EC2 service to assume this role.
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# This block attaches a policy to the "ecs_role" IAM role.
# The policy being attached provides the permissions necessary for ECS to make calls to AWS APIs on your behalf.
resource "aws_iam_role_policy_attachment" "ecs_role_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# This block attaches another policy to the "ecs_role" IAM role.
# The policy being attached provides read-only access to Amazon ECR (Elastic Container Registry).
# This allows ECS tasks to pull Docker images from ECR.
resource "aws_iam_role_policy_attachment" "ecs_ecr_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# This creates an IAM instance profile that we can associate with our EC2 instances.
# EC2 instances use instance profiles to make secure API requests.
# Here, we are associating the "ecs_role" IAM role with the instance profile.
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_role.name
}
```

This code creates an ECS cluster named devninja_worker and sets a series of permission policies for it.

Now that we have our cluster, we should add an instance (EC2) to it.

To add an instance to AWS ECS, it is necessary that it has a compatible Amazon Machine Image (AMI) (Amazon ECS-optimized Amazon Linux 2 AMI). Furthermore, when the machine starts, it must run the startup command.

We will create a folder called assets and, inside it, the file ecs-instance.sh:

assets/ecs-instance.sh:

```sh
#!/bin/bash
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
```

This script sets the ECS_CLUSTER variable in the ECS configuration file, which specifies to which cluster the EC2 instance will belong.

We continue the configuration with the aws-ecs-ec2.tf file:

```sh
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
```

This code creates an EC2 instance and connects it to our ECS cluster. Note that we are using the latest version of the ECS-optimized AMI in a t3.small instance type.

Now that we have the AWS ECS cluster set up and an EC2 machine integrated with it, we should be able to upload our Dockerfile to AWS. For this, we will use AWS ECR and the aws-ecr.tf file:

```sh
# This resource block creates an AWS ECR (Elastic Container Registry) repository.
resource "aws_ecr_repository" "devninja_ecr_1" {

  # The 'name' attribute specifies the name of the ECR repository.
  name = "devninja_ecr_1"

  # The 'image_tag_mutability' attribute determines whether image tags can be overwritten.
  # Setting this to 'MUTABLE' allows existing image tags to be overwritten by subsequent pushes.
  image_tag_mutability = "MUTABLE"

  # The 'image_scanning_configuration' block is used to configure image scanning settings for the repository.
  image_scanning_configuration {

    # The 'scan_on_push' attribute determines whether images are scanned for vulnerabilities upon being pushed to the repository.
    # Setting this to 'true' enables automatic scanning upon each push.
    scan_on_push = true
  }
}
```

This code creates an ECR repository called devninja_ecr_1, where we will store our Docker images.

Finally, it’s time to run our container in an ECS service. Each service requires a ‘task definition’. An AWS ECS task definition is a JSON file that describes one or more containers that make up your application. This definition specifies the container settings, including the resources they need, such as CPU and memory, which Docker images to use, which network ports to expose, and much more. It is, in essence, the ‘recipe’ for your application within the AWS ECS environment.

For this, we will create the aws-ecs-task.tf file:

```sh
# Setting up logging with CloudWatch
resource "aws_cloudwatch_log_group" "devninja_worker_nodejs" {
  name = "/ecs/devninja_worker_nodejs"
  retention_in_days = 14  # Logs will be retained for 14 days
}

# Task Definition (We will use the Apache image as an example)
resource "aws_ecs_task_definition" "devninja_worker_nodejs" {
  family                   = "devninja_worker_nodejs"
  network_mode             = "bridge"  # Using bridge network mode
  cpu                      = "256"  # CPU value for the task
  memory                   = "128"  # Memory value for the task
  requires_compatibilities = ["EC2"]  # This task requires EC2 compatibility

  # Container definitions specify the Docker image and configuration options for each container in the task
  container_definitions = <<DEFINITION
  [
    {
      "name": "devninja_worker_nodejs",
      "image": "${aws_ecr_repository.devninja_ecr_1.repository_url}:main",  # Using the Docker image from our ECR repository
      "cpu": 256,
      "memory": 128,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/devninja_worker_nodejs",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
}

# Adding our task to the cluster
resource "aws_ecs_service" "devninja_worker_nodejs" {
  name            = "devninja_worker_nodejs"
  cluster         = aws_ecs_cluster.devninja_worker.id
  task_definition = aws_ecs_task_definition.devninja_worker_nodejs.arn
  desired_count   = 1  # We want one running instance of this task
  launch_type     = "EC2"  # This service will run on EC2 instances
}
```

This block of code does several things. First, it creates a CloudWatch log group that will store the logs of our application. Then, it defines a ‘task definition’ for a container holding our AWS ECR image, including the amount of CPU and memory that the container should use, and the log configuration that the container should follow and the ports that need to be opened by the container.

Finally, it adds our ‘task definition’ to our ECS cluster. Note that we are using the “EC2” launch type, which means that our container will run on an EC2 instance.

At this point, we have an ECS cluster configured and running with a single service. But how can we ensure that changes to our code are reflected in our service? The answer is Gitlab CI.

To be continued… I hope you’ve found this guide helpful so far. If you have any questions or suggestions, please don’t hesitate to leave a comment below!