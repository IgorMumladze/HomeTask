terraform {
  backend "s3" {
    bucket         = "igor-tfstate-bucket"
    key            = "my-app/prod/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "my-tf-locks"
    encrypt        = true
  }
}

