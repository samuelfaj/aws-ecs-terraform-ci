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