# FlowPay 常用开发命令。在仓库根目录执行：make <目标>
# 兼容 Windows (MSYS2/Git Bash) 与 Linux/macOS
ifeq ($(OS),Windows_NT)
  PYTHON ?= python
  VENV   := backend/.venv/Scripts/python.exe
else
  PYTHON ?= python3
  VENV   := backend/.venv/bin/python
endif

.DEFAULT_GOAL := help
CONFIG := backend/configs/local.toml

STAGE      ?= s1
STAGES     ?= s1,s2,s3,s4
PER_TYPE   ?= 2
SETUP_ARGS ?=

DB_HOST := 127.0.0.1:55432/flowpay_knowledge
define with-env
	set -a; [ -f .env ] && . ./.env; \
	[ -n "$$FLOWPAY_DATASET_ROOT" ] && FLOWPAY_DATASET_PATH="$$FLOWPAY_DATASET_ROOT/data"; \
	FLOWPAY_DB_PASSWORD="$${FLOWPAY_DB_PASSWORD:-flowpay_local}"; \
	FLOWPAY_KNOWLEDGE_ADMIN_DSN="postgresql://flowpay_admin:$$FLOWPAY_DB_PASSWORD@$(DB_HOST)"; \
	FLOWPAY_KNOWLEDGE_DSN="postgresql://flowpay_knowledge_reader:$$FLOWPAY_DB_PASSWORD@$(DB_HOST)"; \
	FLOWPAY_KNOWLEDGE_BUILDER_DSN="postgresql://flowpay_knowledge_builder:$$FLOWPAY_DB_PASSWORD@$(DB_HOST)"; set +a;
endef

.PHONY: help up down logs setup doctor db-up db-setup run frontend test quality verify-db

help: ## 列出可用目标
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

##@ 路径

up: ## 起全栈：校验 .env、备好数据库、知识库与嵌入模型，再起全部容器
	$(PYTHON) scripts/start.py $(if $(BUILD),--build)

down: ## 停止全栈容器，数据卷保留（知识库与嵌入模型不会丢）
	docker compose down

logs: ## 跟踪后端与前端日志
	docker compose logs -f backend frontend

##@ 宿主机直跑

setup: ## 一键准备本地配置、依赖、数据库与知识集合（含 uv sync）
	$(PYTHON) scripts/setup.py $(SETUP_ARGS)

doctor: ## 只读检查基础环境，不安装依赖也不调用聊天模型
	$(PYTHON) scripts/doctor.py $(SETUP_ARGS)

db-up: ## 只起 PostgreSQL（make up 会自己带上它）
	docker compose up -d --wait postgres

db-setup: ## 执行知识库结构迁移与角色授权（setup 已包含，升级旧库时单独跑）
	@$(with-env) $(VENV) scripts/database.py setup

run: ## 课程后端（STAGE 可选 s1—s4）
	@$(with-env) $(VENV) -m flowpay --config $(CONFIG) --stage $(STAGE)

frontend: ## 前端开发服务器
	npm --prefix frontend run dev

##@ 开发与验证

verify-db: ## 验证数据库结构、切片与向量检索完整性
	@$(with-env) $(VENV) scripts/test_knowledge_db.py

test: ## 跑后端 pytest
	@$(with-env) $(VENV) -m pytest backend/tests -q

quality: ## 代码质量门禁：ruff、basedpyright、pytest
	@$(with-env) $(VENV) scripts/check_quality.py
