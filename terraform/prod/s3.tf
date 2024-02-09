provider "aws" {
  alias  = "s3_bucket_provider"
  region = var.region
}

module "secondary_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  providers = {
    aws = aws.s3_bucket_provider
  }

  bucket = "matrix-reload-secondary"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  force_destroy = true

  lifecycle_rule = [{
    enabled = true,
    expiration = {
      days = 365
    },
    id     = "expire-older-versions",
    prefix = "",
    status = "Enabled",
    transitions = [{
      days          = 30,
      storage_class = "STANDARD_IA"
    }]
  }]

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::matrix-reload-secondary",
        "arn:aws:s3:::matrix-reload-secondary/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF
  tags = {
    Name        = "matrix-prod-${terraform.workspace}"
    Environment = "prod"
  }
}
