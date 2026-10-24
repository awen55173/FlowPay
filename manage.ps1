<#
.SYNOPSIS
  FlowPay Windows 项目管理脚本 (1:1 完整对标 Makefile)
.DESCRIPTION
  统一在 Windows 上执行全栈容器、本地环境准备、数据库、前后端服务、测试与质量门禁。
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet(
        "help", "setup", "doctor", "db-up", "db-setup", "up", "down", "logs", 
        "run", "frontend", "test", "quality", "benchmark", "blueprints", 
        "demo", "smoke", "verify-db", "test-ollama", "test-embedder"
    )]
    [string]$Target = "help",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ROOT = $PSScriptRoot
$VENV_PYTHON = Join-Path $ROOT "backend\.venv\Scripts\python.exe"
$CONFIG = "backend/configs/local.toml"

function Invoke-Py {
    param([Parameter(ValueFromRemainingArguments=$true)]$ArgsList)
    if (Test-Path $VENV_PYTHON) {
        & $VENV_PYTHON @ArgsList
    } elseif (Get-Command uv -ErrorAction SilentlyContinue) {
        & uv run python @ArgsList
    } else {
        & python @ArgsList
    }
}

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
    Write-Host "FlowPay Windows 常用开发命令 (完整对标 Makefile):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "【全栈路径 (Docker 容器)】" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 up             起全栈：校验 .env、备好数据库、知识库与嵌入模型，起全部容器"
    Write-Host "  .\manage.ps1 down           停止全栈容器，数据卷保留"
    Write-Host "  .\manage.ps1 logs           跟踪后端与前端容器日志"
    Write-Host ""
    Write-Host "【宿主机直跑 (开发与调试)】" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 setup          一键准备本地配置、依赖、数据库与知识集合 (含 uv sync)"
    Write-Host "  .\manage.ps1 doctor         只读检查基础环境，不安装依赖也不调用聊天模型"
    Write-Host "  .\manage.ps1 db-up          只起 PostgreSQL 容器"
    Write-Host "  .\manage.ps1 db-setup       执行知识库结构迁移与角色授权"
    Write-Host "  .\manage.ps1 run            启动后端服务 (可通过 -Stage s1/s2/s3/s4 指定阶段)"
    Write-Host "  .\manage.ps1 frontend       启动前端开发服务器 (Vite dev)"
    Write-Host ""
    Write-Host "【开发与质量门禁】" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 test           只跑 backend pytest"
    Write-Host "  .\manage.ps1 quality        运行代码质量门禁 (ruff / pyright / pytest / 前端构建)"
    Write-Host "  .\manage.ps1 demo           起确定性契约后端，只验协议不跑课程阶段"
    Write-Host "  .\manage.ps1 smoke          对着已在跑的后端验 HTTP/SSE：断线回放、取消与继续"
    Write-Host "  .\manage.ps1 benchmark      数据集 300 题分层评测对照"
    Write-Host "  .\manage.ps1 blueprints     将 300 题渲染成可读 Markdown"
    Write-Host ""
    Write-Host "【模块自检工具】" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 verify-db      运行 test_knowledge_db.py 验证知识库完整性"
    Write-Host "  .\manage.ps1 test-ollama    运行 test_ollama.py 测试 Ollama 原生端点"
    Write-Host "  .\manage.ps1 test-embedder  运行 test_embedder.py 测试 Python 嵌入客户端"
    Write-Host ""
}

# 确保在仓库根目录执行
Push-Location $ROOT

try {
    switch ($Target) {
        "help" {
            Show-Help
        }
        "up" {
            Load-Env
            Invoke-Py scripts/start.py @ExtraArgs
        }
        "down" {
            docker compose down @ExtraArgs
        }
        "logs" {
            docker compose logs -f backend frontend
        }
        "setup" {
            Load-Env
            Invoke-Py scripts/setup.py @ExtraArgs
        }
        "doctor" {
            Load-Env
            Invoke-Py scripts/doctor.py @ExtraArgs
        }
        "db-up" {
            docker compose up -d --wait postgres
        }
        "db-setup" {
            Load-Env
            Invoke-Py scripts/database.py setup
        }
        "run" {
            Load-Env
            $stage = if ($env:STAGE) { $env:STAGE } else { "s1" }
            Invoke-Py -m flowpay --config $CONFIG --stage $stage @ExtraArgs
        }
        "frontend" {
            npm --prefix frontend run dev
        }
        "test" {
            Load-Env
            Invoke-Py -m pytest backend/tests -q @ExtraArgs
        }
        "quality" {
            Load-Env
            Invoke-Py scripts/check_quality.py @ExtraArgs
        }
        "benchmark" {
            Load-Env
            Invoke-Py scripts/benchmark/run.py --stages s1,s2,s3,s4 --per-type 2 @ExtraArgs
        }
        "blueprints" {
            Load-Env
            Invoke-Py scripts/benchmark/render.py @ExtraArgs
        }
        "demo" {
            Load-Env
            Invoke-Py scripts/demo.py --config $CONFIG @ExtraArgs
        }
        "smoke" {
            Load-Env
            Invoke-Py scripts/smoke_runtime.py @ExtraArgs
        }
        "verify-db" {
            Load-Env
            Invoke-Py scripts/test_knowledge_db.py
        }
        "test-ollama" {
            Load-Env
            Invoke-Py scripts/test_ollama.py
        }
        "test-embedder" {
            Load-Env
            Invoke-Py scripts/test_embedder.py
        }
    }
} finally {
    Pop-Location
}
