terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project_name, ManagedBy = "Terraform" } }
}

data "aws_availability_zones" "available" { state = "available" }
resource "random_id" "suffix" { byte_length = 4 }

resource "aws_vpc" "platform" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.platform.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.platform.cidr_block, 8, count.index)
}

resource "aws_security_group" "msk" {
  name_prefix = "${var.project_name}-msk-"
  description = "IAM-authenticated Kafka traffic inside the application security group"
  vpc_id      = aws_vpc.platform.id

  ingress {
    from_port = 9098
    to_port   = 9098
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_msk_serverless_cluster" "events" {
  cluster_name = "${var.project_name}-events"
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.msk.id]
  }
  client_authentication { sasl { iam { enabled = true } } }
}

resource "aws_s3_bucket" "checkpoints" {
  bucket = "${var.project_name}-checkpoints-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "checkpoints" {
  bucket                  = aws_s3_bucket.checkpoints.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_versioning" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_cloudwatch_log_group" "streaming" {
  name              = "/aws/${var.project_name}/streaming"
  retention_in_days = 30
}

