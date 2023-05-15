resource "aws_ecr_repository" "devninja_ecr_1" {
  name                 = "devninja_ecr_1"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}