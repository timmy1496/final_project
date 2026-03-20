terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # S3 backend — після першого apply налаштуй backend і зроби terraform init -migrate-state
  backend "s3" {
    bucket         = "go-app-terraform-state-dev"   # замінити на свій
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "go-app-terraform-state-dev-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ─── S3 Backend Bootstrap ───────────────────────────────────
# Запускати ОДИН РАЗ перед налаштуванням backend блоку:
#   terraform init -backend=false
#   terraform apply -target=module.s3_backend
# Потім налаштувати backend блок і: terraform init -migrate-state

module "s3_backend" {
  source      = "../../modules/s3-backend"
  bucket_name = "${var.project_name}-terraform-state-${var.environment}"
  common_tags = var.common_tags
}

# ─── VPC ────────────────────────────────────────────────────
module "vpc" {
  source               = "../../modules/vpc"
  project_name         = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags          = var.common_tags
}

# ─── ECR ────────────────────────────────────────────────────
module "ecr" {
  source           = "../../modules/ecr"
  repository_name  = "${var.project_name}-${var.environment}"
  max_image_count  = 20
  common_tags      = var.common_tags
}

# ─── RDS MySQL ──────────────────────────────────────────────
module "rds" {
  source               = "../../modules/rds"
  project_name         = "${var.project_name}-${var.environment}"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  allowed_cidr_blocks  = [var.vpc_cidr]
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_class       = var.rds_instance_class
  database_name        = var.db_name
  deletion_protection  = var.environment == "prod" ? true : false
  multi_az             = var.environment == "prod" ? true : false
  common_tags          = var.common_tags
}

# ─── EKS ────────────────────────────────────────────────────
module "eks" {
  source               = "../../modules/eks"
  project_name         = "${var.project_name}-${var.environment}"
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  kubernetes_version   = var.kubernetes_version
  node_instance_types  = var.node_instance_types
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  ec2_ssh_key_name     = var.ec2_ssh_key_name
  common_tags          = var.common_tags
}

# ─── Ansible Inventory (auto-generated) ─────────────────────
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    ecr_url          = module.ecr.repository_url
    rds_endpoint     = module.rds.endpoint
    aws_region       = var.aws_region
    environment      = var.environment
  })
  filename        = "${path.module}/../../../ansible/inventory/hosts.ini"
  file_permission = "0644"
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/group_vars.tmpl", {
    cluster_name         = module.eks.cluster_name
    ecr_repository_url   = module.ecr.repository_url
    rds_endpoint         = module.rds.endpoint
    db_name              = var.db_name
    aws_region           = var.aws_region
    environment          = var.environment
    alb_controller_role  = module.eks.alb_controller_role_arn
  })
  filename        = "${path.module}/../../../ansible/group_vars/all.yml"
  file_permission = "0644"
}
