module "ecr" {
  source       = "../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
  repositories = var.ecr_repositories
  tags         = var.tags
}

