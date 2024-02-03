provider "aws" {
  alias  = "s3_bucket_provider"
  region = var.region
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  providers = {
    aws = aws.s3_bucket_provider
  }

  bucket = "matrix-revolution"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}
