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