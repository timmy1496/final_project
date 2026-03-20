.PHONY: help tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy ansible-deploy ansible-monitoring k8s-deploy verify clean

ENV        ?= dev
TF_DIR     := terraform/environments/$(ENV)
ANS_DIR    := ansible
GREEN      := \033[0;32m
YELLOW     := \033[0;33m
RED        := \033[0;31m
NC         := \033[0m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'

# ─── Terraform ────────────────────────────────────────────────
tf-init: ## terraform init
	cd $(TF_DIR) && terraform init

tf-fmt: ## terraform fmt (auto-fix)
	terraform fmt -recursive terraform/

tf-fmt-check: ## terraform fmt check only
	terraform fmt -check -recursive terraform/

tf-validate: tf-fmt-check ## terraform validate
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

tf-scan: ## Security scan with tfsec + checkov
	@which tfsec > /dev/null || (curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash)
	tfsec terraform/ --soft-fail
	@which checkov > /dev/null || pip3 install checkov --break-system-packages
	checkov -d terraform/ --framework terraform --soft-fail

tf-plan: ## terraform plan (ENV=dev|prod)
	@echo "$(GREEN)▶ Planning $(ENV) environment...$(NC)"
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars -out=tfplan

tf-apply: ## terraform apply — MANUAL, requires plan first
	@echo "$(YELLOW)⚠️  Applying to $(ENV)...$(NC)"
	@read -p "Continue? [yes/no]: " c && [ "$$c" = "yes" ] || exit 1
	cd $(TF_DIR) && terraform apply tfplan

tf-destroy: ## terraform destroy — MANUAL, DANGEROUS
	@echo "$(RED)⚠️  DESTROYING $(ENV) infrastructure!$(NC)"
	@read -p "Type DESTROY to confirm: " c && [ "$$c" = "DESTROY" ] || exit 1
	cd $(TF_DIR) && terraform destroy -var-file=terraform.tfvars -auto-approve

tf-output: ## Show terraform outputs
	cd $(TF_DIR) && terraform output

# ─── Bootstrap (перший запуск) ───────────────────────────────
bootstrap: ## First run: create S3 backend, then migrate state
	@echo "$(GREEN)▶ Step 1: Create S3 backend$(NC)"
	cd $(TF_DIR) && terraform init -backend=false
	cd $(TF_DIR) && terraform apply -target=module.s3_backend -var-file=terraform.tfvars -auto-approve
	@echo "$(GREEN)▶ Step 2: Uncomment backend block in main.tf, then run: make tf-init$(NC)"

# ─── Ansible ─────────────────────────────────────────────────
ansible-deploy: ## Full ansible deploy (k8s tools + app + monitoring)
	cd $(ANS_DIR) && ansible-playbook -i inventory/hosts.ini site.yml

ansible-k8s: ## Install k8s tools only
	cd $(ANS_DIR) && ansible-playbook -i inventory/hosts.ini site.yml --tags k8s-tools

ansible-monitoring: ## Deploy monitoring only
	cd $(ANS_DIR) && ansible-playbook -i inventory/hosts.ini site.yml --tags monitoring

# ─── Kubernetes ──────────────────────────────────────────────
k8s-apply: ## Apply k8s manifests
	kubectl apply -f k8s/app/ -n app

k8s-status: ## Show app status
	@kubectl get pods,svc,ingress -n app
	@echo ""
	@kubectl get pods -n monitoring

k8s-logs: ## Tail app logs
	kubectl logs -f -l app=go-app -n app --all-containers

grafana-url: ## Get Grafana URL and credentials
	@echo "URL:      http://$$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
	@echo "User:     admin"
	@echo "Password: $$(kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d)"

# ─── ECR ─────────────────────────────────────────────────────
ecr-login: ## Login to ECR
	aws ecr get-login-password --region eu-central-1 | \
		docker login --username AWS --password-stdin \
		$$(cd $(TF_DIR) && terraform output -raw ecr_repository_url | cut -d/ -f1)

ecr-push: ## Build and push image to ECR (TAG=v1.0.0)
	$(eval ECR_URL := $(shell cd $(TF_DIR) && terraform output -raw ecr_repository_url))
	docker build -t $(ECR_URL):$(TAG) -t $(ECR_URL):latest ./app
	docker push $(ECR_URL):$(TAG)
	docker push $(ECR_URL):latest

# ─── Full Deploy ─────────────────────────────────────────────
deploy: tf-init tf-plan tf-apply ansible-deploy k8s-apply ## Full deploy pipeline
	@echo "$(GREEN)🎉 Deployment complete!$(NC)"
	@$(MAKE) k8s-status

clean: ## Clean terraform local files
	find terraform/ -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform/ -name "tfplan" -delete 2>/dev/null || true
	find terraform/ -name ".terraform.lock.hcl" -delete 2>/dev/null || true
