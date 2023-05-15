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