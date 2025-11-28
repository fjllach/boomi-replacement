provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localstack:4566"
    lambda         = "http://localstack:4566"
    stepfunctions  = "http://localstack:4566"
    iam            = "http://localstack:4566"
    events         = "http://localstack:4566"
    sts            = "http://localstack:4566"
    appflow        = "http://localstack:4566" # AppFlow might not work, but mapping it anyway
  }
}
