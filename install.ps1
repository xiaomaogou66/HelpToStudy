#Requires -Version 5.1
<#
.SYNOPSIS
    AI 学习工作流 · 一键安装脚本
.DESCRIPTION
    在一台新电脑上复现「AI 学习工作流」Obsidian 库：
      0. 交互模式下会先弹出「选择文件夹」对话框，由你决定库的安装位置
         （取消则询问是否用默认位置；-NoDialog 可跳过对话框）
      1. 在目标位置创建完整的库目录结构
      2. 复制模板、提示词、Claude 斜杠命令、Obsidian 配置与插件
      3. 创建 Python 虚拟环境并安装拆书依赖（含可选 MinerU 云端 OCR）
      4. 生成带本机路径的拆书启动器（_工具/*.bat）
      5. 可选：安装完成后直接用 Obsidian 打开该库
    用法（在仓库根目录的 PowerShell 中执行）：
      .\install.ps1
      .\install.ps1 -VaultPath "D:\我的资料\AI学习工作流" -OpenObsidian
      .\install.ps1 -SkipPython -SkipMineru
.PARAMETER VaultPath
    库的安装位置（默认 %USERPROFILE%\ObsidianVaults\AI学习工作流）
.PARAMETER PythonPath
    指定 python.exe 路径（默认自动查找）
.PARAMETER SkipPython
    跳过 Python 虚拟环境与依赖安装
.PARAMETER SkipMineru
    跳过 MinerU 云端 OCR 命令行工具安装
.PARAMETER SkipPlugins
    跳过 Obsidian 插件复制
.PARAMETER OpenObsidian
    安装完成后用 Obsidian 打开该库
.PARAMETER NoDialog
    不弹出文件夹选择对话框（直接使用默认位置；适合脚本化/无人值守安装）
.PARAMETER Force
    目标目录已存在时不再询问，直接继续
.EXAMPLE
    .\install.ps1 -OpenObsidian
.EXAMPLE
    .\install.ps1 -NoDialog -SkipPython
#>
param(
    [string]$VaultPath = "",
    [string]$PythonPath = "",
    [switch]$SkipPython,
    [switch]$SkipMineru,
    [switch]$SkipPlugins,
    [switch]$OpenObsidian,
    [switch]$NoDialog,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ---------- 工具函数 ----------
function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "  [完成] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [提示] $msg" -ForegroundColor Yellow }

function Invoke-PipWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$PipExe,
        [Parameter(Mandatory = $true)][string[]]$PipArgs,
        [Parameter(Mandatory = $true)][string]$Label
    )
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        & $PipExe @PipArgs
        if ($LASTEXITCODE -eq 0) { return }
        if ($attempt -lt 3) {
            Write-Warn "$Label 第 $attempt 次尝试失败，5 秒后自动重试（网络波动常见，最多重试 3 次）"
            Start-Sleep -Seconds 5
        }
    }
    throw "$Label 安装失败，请检查网络后重新运行 install.ps1"
}

# ---------- 读取配置 ----------
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VaultName = "AI学习工作流"
$cfg = @{}
$cfgPath = Join-Path $RepoRoot "workflow.config.json"
if (Test-Path -LiteralPath $cfgPath) {
    try {
        $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-OK "已读取配置文件 workflow.config.json"
    } catch {
        Write-Warn "配置文件解析失败，改用命令行参数与默认值"
    }
}
if (-not $VaultPath -and $cfg.vaultPath) { $VaultPath = [string]$cfg.vaultPath }
if (-not $PythonPath -and $cfg.pythonPath) { $PythonPath = [string]$cfg.pythonPath }
if (-not $SkipMineru -and $cfg.installMineru -eq $false) { $SkipMineru = $true }

$defaultVaultPath = Join-Path $env:USERPROFILE "ObsidianVaults\$VaultName"
if (-not $VaultPath) {
    $VaultPath = $defaultVaultPath
    # 方案 B：交互模式下弹出「选择文件夹」对话框，让用户自选库的位置。
    # 所选文件夹将直接作为库目录（与 -VaultPath 语义一致）。
    if (-not $NoDialog -and [Environment]::UserInteractive) {
        try {
            Add-Type -AssemblyName System.Windows.Forms | Out-Null
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "请选择「AI 学习工作流」库的安装位置：" +
                "所选文件夹将直接作为库目录（默认：$defaultVaultPath）"
            $dialog.SelectedPath = Split-Path -Parent $defaultVaultPath
            $dialog.ShowNewFolderButton = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
                $VaultPath = $dialog.SelectedPath
                Write-OK "已选择安装位置：$VaultPath"
            } else {
                $ans = Read-Host "未选择位置。使用默认位置 $defaultVaultPath ？(Y/N)"
                if ($ans -notmatch "^[yY]") { Write-Host "已取消安装"; exit 1 }
            }
            $dialog.Dispose()
        } catch {
            Write-Warn "无法弹出文件夹选择对话框，将使用默认位置：$defaultVaultPath"
            $VaultPath = $defaultVaultPath
        }
    }
}
$VaultPath = [System.IO.Path]::GetFullPath($VaultPath)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   AI 学习工作流 · 一键安装" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   安装位置: $VaultPath"

# 已存在处理
if (Test-Path -LiteralPath $VaultPath) {
    $existing = (Get-ChildItem -LiteralPath $VaultPath -Force -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($existing -gt 0 -and -not $Force) {
        Write-Warn "目标目录已存在且非空：$VaultPath"
        $ans = Read-Host "继续会覆盖其中的模板/命令/工具文件（个人笔记不受影响）。输入 y 继续"
        if ($ans -notmatch "^[yY]") { Write-Host "已取消安装"; exit 1 }
    }
    if ($existing -gt 0) { Write-Warn "目标目录已存在：保留现有个人笔记，覆盖/补充工作流文件" }
}

# ---------- 1. 创建目录 ----------
Write-Step "第 1 步：创建库目录结构"
$dirs = @(
    "00-使用指南", "01-提示词库", "02-模板", "03-学习主题", "04-教材分块",
    "_工具", "_备份", "copilot\copilot-custom-prompts", "images"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $VaultPath $d) | Out-Null
}
Write-OK "目录结构已就绪"

# ---------- 2. 复制内容 ----------
Write-Step "第 2 步：复制模板 / 提示词 / 命令 / 配置"
$copyDirs = @("00-使用指南", "01-提示词库", "02-模板", ".claude", "copilot", ".obsidian")
foreach ($d in $copyDirs) {
    $src = Join-Path $RepoRoot $d
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ($d -eq ".obsidian" -and $SkipPlugins) {
        robocopy $src (Join-Path $VaultPath $d) /E /XD plugins /XF data.json workspace.json /NFL /NDL /NJH /NJS /R:2 /W:1 | Out-Null
    } else {
        robocopy $src (Join-Path $VaultPath $d) /E /XF data.json workspace.json /NFL /NDL /NJH /NJS /R:2 /W:1 | Out-Null
    }
    if ($LASTEXITCODE -ge 8) { throw "复制 $d 失败（错误码 $LASTEXITCODE）" }
}
Copy-Item -LiteralPath (Join-Path $RepoRoot "03-学习主题\📌 从这里开始.md") -Destination (Join-Path $VaultPath "03-学习主题\") -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "04-教材分块\📖 教材分块说明.md") -Destination (Join-Path $VaultPath "04-教材分块\") -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "AGENTS.md") -Destination $VaultPath -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "CLAUDE.md") -Destination $VaultPath -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "_工具\split_textbook.py") -Destination (Join-Path $VaultPath "_工具\") -Force
Write-OK "内容复制完成"

# ---------- 3. Python 环境 ----------
$venvPy = Join-Path $VaultPath "_工具\.venv\Scripts\python.exe"
$py = ""
if (-not $SkipPython) {
    Write-Step "第 3 步：创建 Python 虚拟环境并安装拆书依赖"
    $py = $PythonPath
    if (-not $py) {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command py -ErrorAction SilentlyContinue }
        if ($cmd) { $py = $cmd.Source }
    }
    if (-not $py) {
        $candidates = @(
            "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
            "$env:ProgramFiles\Python313\python.exe",
            "$env:ProgramFiles\Python312\python.exe",
            "$env:ProgramFiles\Python311\python.exe"
        )
        $py = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $py) {
        throw "未找到 Python。请先安装 Python 3.10+（https://www.python.org/downloads/），或用 -PythonPath 参数指定 python.exe"
    }
    Write-Host "  使用 Python: $py"
    if (-not (Test-Path -LiteralPath $venvPy)) {
        & $py -m venv (Join-Path $VaultPath "_工具\.venv")
        if ($LASTEXITCODE -ne 0) { throw "创建 Python 虚拟环境失败" }
    }
    Invoke-PipWithRetry -PipExe $venvPy -PipArgs @("-m", "pip", "install", "--disable-pip-version-check", "-q", "-r", (Join-Path $RepoRoot "requirements.txt")) -Label "拆书依赖"
    Write-OK "拆书依赖已安装（pdfplumber / pypdf / python-docx / lxml）"

    if (-not $SkipMineru) {
        try {
            Invoke-PipWithRetry -PipExe $venvPy -PipArgs @("-m", "pip", "install", "--disable-pip-version-check", "-q", "mineru-open-api") -Label "MinerU 工具"
            Write-OK "MinerU 云端 OCR 工具已安装"
        } catch {
            Write-Warn "MinerU 工具安装失败，可稍后手动执行：_工具\.venv\Scripts\pip.exe install mineru-open-api"
        }
    }
} else {
    Write-Warn "已跳过 Python 环境安装（-SkipPython）"
}

# ---------- 4. 生成启动器 ----------
Write-Step "第 4 步：生成拆书启动器（_工具/*.bat）"
$launcherDir = Join-Path $RepoRoot "launchers"
$tokenFile = Join-Path $VaultPath "_工具\mineru_token.txt"
$pythonForBat = ""
if (Test-Path -LiteralPath $venvPy) {
    $pythonForBat = $venvPy
} elseif ($py) {
    $pythonForBat = $py
} else {
    $pythonForBat = "python"
}

# 查找 MinerU CLI：优先本库虚拟环境，其次常见位置
$mineruCandidates = @(
    (Join-Path $VaultPath "_工具\.venv\Scripts\mineru-open-api.exe"),
    "D:\obsidian-vault-mcp\.venv\Scripts\mineru-open-api.exe",
    "C:\obsidian-vault-mcp\.venv\Scripts\mineru-open-api.exe",
    (Join-Path $env:USERPROFILE "obsidian-vault-mcp\.venv\Scripts\mineru-open-api.exe")
)
$mineruCli = $mineruCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $mineruCli) { $mineruCli = $mineruCandidates[0] }

$gbk = [System.Text.Encoding]::GetEncoding(936)
if (Test-Path -LiteralPath $launcherDir) {
    foreach ($tpl in Get-ChildItem -LiteralPath $launcherDir -Filter "*.template") {
        $content = Get-Content -LiteralPath $tpl.FullName -Raw -Encoding UTF8
        $content = $content.Replace("{{VAULT_PATH}}", $VaultPath).Replace("{{PYTHON}}", $pythonForBat).Replace("{{TOKEN_FILE}}", $tokenFile).Replace("{{MINERU_CLI}}", $mineruCli)
        $outName = $tpl.BaseName
        [System.IO.File]::WriteAllText((Join-Path $VaultPath "_工具\$outName"), $content, $gbk)
    }
    Write-OK "启动器已生成（自动填入本机路径）"
} else {
    Write-Warn "未找到 launchers 模板目录，跳过启动器生成"
}

# ---------- 5. 收尾 ----------
Write-Step "第 5 步：收尾"
Write-Host ""
Write-Host "============== 安装完成 ==============" -ForegroundColor Green
Write-Host "  库位置: $VaultPath"
Write-Host ""
Write-Host "  接下来："
Write-Host "  1) 用 Obsidian 打开该文件夹（作为库）"
Write-Host "  2) 首次打开若提示「信任社区插件」，请选择信任"
Write-Host "  3) 右侧边栏打开 Claudian，在设置里选择后端（本机 Codex 或 Claude Code）"
Write-Host "  4) 扫描版/数学书才需要：运行 _工具\设置MinerU令牌.bat 保存 Token"
Write-Host "  5) 打开 00-使用指南\📖 使用说明.md 开始使用"
Write-Host "======================================" -ForegroundColor Green

if ($OpenObsidian) {
    $obsidianUri = "obsidian://open?path=" + [uri]::EscapeDataString($VaultPath)
    Start-Process $obsidianUri
    Write-OK "已尝试用 Obsidian 打开该库"
}
