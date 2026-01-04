module "storage" {
  source             = "../modules/storage"
  project_name       = var.project_name
  environment        = var.environment
  aws_account_id     = data.aws_caller_identity.current.account_id
  versioning_enabled = var.s3_versioning_enabled
  bucket_suffix      = var.bucket_suffix
  enable_public_access_block = var.enable_public_access_block
  tags               = var.tags
}

