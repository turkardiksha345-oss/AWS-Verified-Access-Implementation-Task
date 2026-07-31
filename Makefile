.PHONY: help lint test plan validate fmt cedar-validate

TF_DIR := terraform
ENV_DIR := environments/dev

help:
	@echo "Secure Access Portal — Makefile targets"
	@echo "  make lint           Run Python and Terraform lint"
	@echo "  make test           Run unit tests"
	@echo "  make validate       Terraform validate"
	@echo "  make fmt            Terraform format"
	@echo "  make plan           Terraform plan (dev)"
	@echo "  make cedar-validate Validate Cedar policy files"

lint:
	cd application && python3 -m ruff check . && python3 -m ruff format --check .
	cd $(TF_DIR) && terraform fmt -check -recursive .

test:
	cd application && python3 -m pip install -q -r requirements.txt -r requirements-dev.txt
	cd application && python3 -m pytest tests/ -v

validate:
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

fmt:
	cd $(TF_DIR) && terraform fmt -recursive .

plan:
	cd $(TF_DIR) && terraform init -backend-config=$(ENV_DIR)/backend.hcl
	cd $(TF_DIR) && terraform plan -var-file=$(ENV_DIR)/terraform.tfvars

cedar-validate:
	@grep -q "Policy 1" cedar/group-policy.cedar
	@grep -q "Policy 4" cedar/group-policy.cedar
	@echo "Cedar policies validated"
