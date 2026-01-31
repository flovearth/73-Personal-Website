terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
  backend "s3" {
    bucket  = "feyz-sari-personal-website-gha-statefiles"
    key     = "personal-website/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Variables ---
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state files"
  type        = string
  default     = "feyz-sari-personal-website-gha-statefiles"
}

variable "bucket_name" {
  description = "S3 bucket name for static website hosting"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in the form owner/repo"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to deploy"
  type        = string
  default     = "main"
}

variable "github_oidc_thumbprint" {
  description = "Thumbprint for GitHub OIDC provider"
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

# --- S3 Bucket for Static Website ---
resource "aws_s3_bucket" "personal_website" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = "prod"
    Project     = "personal-website"
  }
}

resource "aws_s3_bucket_website_configuration" "personal_website" {
  bucket = aws_s3_bucket.personal_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "personal_website" {
  bucket                  = aws_s3_bucket.personal_website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "personal_website_public_read" {
  bucket = aws_s3_bucket.personal_website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.personal_website.arn}/*"
      }
    ]
  })
}

# --- GitHub OIDC Provider ---
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github_oidc_thumbprint]
}

# --- IAM Role for GitHub Actions (OIDC) ---
resource "aws_iam_role" "personal_website_github_actions" {
  name = "personal-website-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "personal_website_github_actions_s3" {
  name = "personal-website-github-actions-s3-policy"
  role = aws_iam_role.personal_website_github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          aws_s3_bucket.personal_website.arn
        ]
      },
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.personal_website.arn}/*"
        ]
      }
    ]
  })
}

# --- S3 Bucket for Terraform State Files ---
# Bucket is created in workflow before Terraform init; reference it here.
data "aws_s3_bucket" "personal_website_statefiles" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_tagging" "personal_website_statefiles" {
  bucket = data.aws_s3_bucket.personal_website_statefiles.id

  tag_set {
    key   = "Name"
    value = var.state_bucket_name
  }

  tag_set {
    key   = "Environment"
    value = "prod"
  }

  tag_set {
    key   = "Project"
    value = "personal-website"
  }
}

# --- Outputs ---
output "personal_website_bucket_name" {
  value = aws_s3_bucket.personal_website.bucket
}

output "personal_website_endpoint" {
  value = aws_s3_bucket_website_configuration.personal_website.website_endpoint
}

output "personal_website_github_actions_role_arn" {
  value = aws_iam_role.personal_website_github_actions.arn
}
