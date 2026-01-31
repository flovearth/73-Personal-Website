# Personal Website (S3 + GitHub Actions + Terraform)

## Overview
This repository deploys a static website to S3 using GitHub Actions and Terraform. It includes:
- A static site (`index.html`, `error.html`)
- Terraform to provision the S3 buckets and GitHub OIDC role
- GitHub Actions workflows for provisioning and deployment

## Prerequisites
- AWS account with permissions to create IAM roles and S3 buckets
- A GitHub repository with Actions enabled

## Terraform variables
Edit [terraform.tfvars](terraform.tfvars) with your values:
- `bucket_name`: S3 bucket for the website
- `github_repo`: in `owner/repo` format
- `github_branch`: branch to allow deploy
- `aws_region`: AWS region

## How to get AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
1) In AWS Console, go to IAM.
2) Create a dedicated IAM user (e.g., `personal-website-terraform-bootstrap`).
3) Attach a policy that allows creating S3 buckets and IAM resources used by Terraform.
4) Create an access key for the user and copy:
   - Access key ID → `AWS_ACCESS_KEY_ID`
   - Secret access key → `AWS_SECRET_ACCESS_KEY`

## How to save secrets in GitHub
In your GitHub repo:
1) Go to Settings → Secrets and variables → Actions.
2) Add these Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
3) Add these Repository Variables:
   - `BUCKET_NAME`
   - `AWS_REGION`
4) Add this Secret (for deployment via OIDC):
   - `AWS_ROLE_ARN`

## How to get the role ARN for AWS_ROLE_ARN
After running Terraform:
- The output `personal_website_github_actions_role_arn` is the role ARN.
- You can also find it in AWS Console → IAM → Roles → `personal-website-github-actions-role`.

## Workflows
- Create AWS resources: [create-aws-resources.yml](.github/workflows/create-aws-resources.yml)
- Deploy site to S3: [deploy-to-s3.yaml](.github/workflows/deploy-to-s3.yaml)

## First-time setup (bootstrap)
1) Add AWS secrets as described above.
2) Run the workflow “Create AWS Resources (Terraform)”.
3) Copy the output role ARN into `AWS_ROLE_ARN` secret.
4) Add `BUCKET_NAME` and `AWS_REGION` repository variables.
5) Push to `main` to trigger deployment.
