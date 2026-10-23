<#
.SYNOPSIS
  FlowPay 项目管理脚本 
.DESCRIPTION
  统一管理环境准备、数据库、全栈启动、测试与门禁。
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("help", "setup", "doctor", "db-up", "db-setup", "up", "down", "logs", "run", "frontend", "verify-db", "test-ollama", "test-embedder", "test", "quality")]
    [string]$Target = "help",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ROOT = $PSScriptRoot
$VENV_PYTHON = Join-Path $ROOT "backend\.venv\Scripts\python.exe"

function Load-Env {
    $envFile = Join-Path $ROOT ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile -Encoding utf8 | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $idx = $line.IndexOf("=")
                if ($idx -gt 0) {
                    $key = $line.Substring(0, $idx).Trim()
                    $val = $line.Substring($idx + 1).Trim().Trim("'").Trim('"')
                    [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
                }
            }
        }
    }
    $password = if ($env:FLOWPAY_DB_PASSWORD) { $env:FLOWPAY_DB_PASSWORD } else { "flowpay_local" }
    $dbHost = "127.0.0.1:55432/flowpay_knowledge"

    if (-not $env:FLOWPAY_KNOWLEDGE_ADMIN_DSN) {
        $env:FLOWPAY_KNOWLEDGE_ADMIN_DSN = "postgresql://flowpay_admin:$password@$dbHost"
    }
    if (-not $env:FLOWPAY_KNOWLEDGE_DSN) {
        $env:FLOWPAY_KNOWLEDGE_DSN = "postgresql://flowpay_knowledge_reader:$password@$dbHost"
    }
    if (-not $env:FLOWPAY_KNOWLEDGE_BUILDER_DSN) {
        $env:FLOWPAY_KNOWLEDGE_BUILDER_DSN = "postgresql://flowpay_knowledge_builder:$password@$dbHost"
    }
    if ($env:FLOWPAY_DATASET_ROOT -and -not $env:FLOWPAY_DATASET_PATH) {
        $env:FLOWPAY_DATASET_PATH = Join-Path $env:FLOWPAY_DATASET_ROOT "data"
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "FlowPay 常用管理命令 (PowerShell 对标 KamaAgenticRAG Makefile):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  .\manage.ps1 setup          一键准备环境：同步配置、uv 依赖、数据库启动与授权"
    Write-Host "  .\manage.ps1 doctor         只读诊断基础工具与环境状态"
    Write-Host "  .\manage.ps1 db-up          只启动 PostgreSQL 容器"
    Write-Host "  .\manage.ps1 db-setup       执行 Alembic 结构迁移与角色权限配置"
    Write-Host "  .\manage.ps1 verify-db      运行 test_knowledge_db.py 验证知识库完整性"
    Write-Host "  .\manage.ps1 test-ollama    运行 test_ollama.py 测试 Ollama 原生端点"
    Write-Host "  .\manage.ps1 test-embedder  运行 test_embedder.py 测试 Python 封装客户端"
    Write-Host "  .\manage.ps1 up             全栈启动容器"
    Write-Host "  .\manage.ps1 down           停止全栈容器并保留数据卷"
    Write-Host "  .\manage.ps1 logs           查看后端和前端容器日志"
    Write-Host "  .\manage.ps1 test           运行后端单元测试 (pytest)"
    Write-Host "  .\manage.ps1 quality        运行代码质量门禁 (ruff / pyright / pytest)"
    Write-Host "  .\manage.ps1 run            在宿主机启动后端服务"
    Write-Host ""
}

switch ($Target) {
    "help" {
        Show-Help
    }
    "setup" {
        Load-Env
        & uv run python scripts/setup.py @ExtraArgs
    }
    "doctor" {
        Load-Env
        & uv run python scripts/doctor.py @ExtraArgs
    }
    "db-up" {
        docker compose up -d --wait postgres
    }
    "db-setup" {
        Load-Env
        & $VENV_PYTHON scripts/database.py setup
    }
    "verify-db" {
        Load-Env
        & $VENV_PYTHON scripts/test_knowledge_db.py
    }
    "test-ollama" {
        Load-Env
        & $VENV_PYTHON scripts/test_ollama.py
    }
    "test-embedder" {
        Load-Env
        & $VENV_PYTHON scripts/test_embedder.py
    }
    "up" {
        Load-Env
        & uv run python scripts/start.py @ExtraArgs
    }
    "down" {
        docker compose down
    }
    "logs" {
        docker compose logs -f backend frontend
    }
    "test" {
        Load-Env
        & $VENV_PYTHON -m pytest backend/tests -q @ExtraArgs
    }
    "quality" {
        Load-Env
        & $VENV_PYTHON scripts/check_quality.py @ExtraArgs
    }
    "run" {
        Load-Env
        $stage = if ($env:STAGE) { $env:STAGE } else { "s1" }
        & $VENV_PYTHON -m flowpay --config backend/configs/local.toml --stage $stage @ExtraArgs
    }
    "frontend" {
        npm --prefix frontend run dev
    }
}
