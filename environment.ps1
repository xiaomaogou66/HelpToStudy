#Requires -Version 5.1
<#
.SYNOPSIS
    AI 学习工作流 · 环境配置脚本
.DESCRIPTION
    检测并安装：Python、Node.js、Git for Windows、Claude Code、cc-switch。
    版本来源优先级：winget > 官方接口 > 内置清单。
    已装且最新 -> 跳过；缺失 -> 自动安装；已装但较旧 -> 询问是否升级
    （-Update 直接升级，不再询问）。
    完成后自动打开 cc-switch，粘贴 API Key 并启用供应商即可配置好 Claudian。
.PARAMETER Update
    检测到旧版本时直接升级，不再询问。
.PARAMETER CheckOnly
    只检测并报告各工具版本状态，不安装任何东西。
.PARAMETER SkipClaude
    跳过 Claude Code 的检测与安装。
.EXAMPLE
    双击 环境配置.bat
    环境配置.bat -CheckOnly
    环境配置.bat -Update
#>
param(
    [switch]$Update,
    [switch]$CheckOnly,
    [switch]$SkipClaude
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"

# ---------- 内置兜底清单（winget 与官方接口都不可用时才用） ----------
$Fallback = @{
    python   = @{
        version  = "3.14.6"
        url      = "https://www.python.org/ftp/python/3.14.6/python-3.14.6-amd64.exe"
        wingetId = "Python.Python.3.14"
    }
    node     = @{
        version  = "24.18.1"
        url      = "https://nodejs.org/dist/v24.18.1/node-v24.18.1-x64.msi"
        wingetId = "OpenJS.NodeJS.LTS"
    }
    git      = @{
        version  = "2.55.0"
        url      = "https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.1/Git-2.55.0-64-bit.exe"
        wingetId = "Git.Git"
    }
    claude   = @{
        version  = "0.0.0"
        url      = ""
        wingetId = "Anthropic.ClaudeCode"
    }
    ccswitch = @{
        version  = "3.16.5"
        url      = "https://github.com/farion1231/cc-switch/releases/download/v3.16.5/CC-Switch-v3.16.5-Windows.msi"
        wingetId = "farion1231.CC-Switch"
    }
}

# ---------- 通用工具函数 ----------
function Write-OK([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [提示] $msg" -ForegroundColor Yellow }
function Write-Info([string]$msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Head([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Compare-Version {
    param([string]$A, [string]$B)
    function Get-Parts([string]$v) {
        $v = ($v -replace "^[vV]", "") -replace "[^0-9.]", ""
        @($v -split "\." | ForEach-Object { if ($_ -match "^\d+$") { [int]$_ } else { 0 } })
    }
    $pa = Get-Parts $A
    $pb = Get-Parts $B
    $n = [Math]::Max($pa.Count, $pb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($x -gt $y) { return 1 }
        if ($x -lt $y) { return -1 }
    }
    return 0
}

function Get-CommandVersion {
    param([string]$Cmd, [string[]]$Args = @("--version"), [string]$Pattern = "(\d+\.\d+(?:\.\d+)+)")
    try {
        $line = (& $Cmd @Args 2>$null | Select-Object -First 1)
        if ($line -and $line -match $Pattern) { return $Matches[1] }
    } catch {}
    return $null
}

function Get-Json {
    param([string]$Url)
    try {
        return Invoke-RestMethod -Uri $Url -TimeoutSec 20 -ErrorAction Stop
    } catch {
        return $null
    }
}

function Invoke-Download {
    param([string]$Url, [string]$Dest)
    Write-Host "    下载: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -TimeoutSec 900 -UseBasicParsing
    if (-not (Test-Path -LiteralPath $Dest)) { throw "下载失败：$Url" }
}

function Ensure-UserPath {
    param([string[]]$Dirs)
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $changed = $false
    foreach ($d in $Dirs) {
        if (-not $userPath) { $userPath = $d; $changed = $true; continue }
        if ($userPath -notlike "*$d*") {
            $userPath = $userPath.TrimEnd(";") + ";" + $d
            $changed = $true
        }
    }
    if ($changed) {
        try { [Environment]::SetEnvironmentVariable("Path", $userPath, "User") } catch {}
    }
    foreach ($d in $Dirs) {
        if ($env:Path -notlike "*$d*") { $env:Path = $d + ";" + $env:Path }
    }
}

# ---------- winget：最新版 / 已装版本（优先级 1） ----------
function Get-WingetLatest {
    param([string]$Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
    try {
        $out = (& winget show --id $Id --exact --accept-source-agreements 2>&1 | Out-String)
        $m = [regex]::Match($out, "(?im)^\s*(?:Version|版本)\s*:\s*([0-9]+\.[0-9]+(?:\.[0-9]+)*)")
        if ($m.Success) { return $m.Groups[1].Value }
    } catch {}
    return $null
}

function Get-WingetInstalled {
    param([string]$Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
    try {
        $out = (& winget list --id $Id --exact 2>&1 | Out-String)
        $m = [regex]::Match($out, [regex]::Escape($Id) + "\s+([0-9]+\.[0-9]+(?:\.[0-9]+)*)")
        if ($m.Success) { return $m.Groups[1].Value }
    } catch {}
    return $null
}

# ---------- 官方接口：各工具最新版（优先级 2） ----------
function Get-Latest-Python {
    $r = Get-Json "https://api.github.com/repos/python/cpython/releases/latest"
    if ($r -and $r.tag_name -match "v?(\d+\.\d+\.\d+)") { return $Matches[1] }
    return $null
}
function Get-Latest-Node {
    $r = Get-Json "https://nodejs.org/dist/index.json"
    if ($r) {
        $lts = $r | Where-Object { $_.lts } | Select-Object -First 1
        if ($lts -and $lts.version -match "v?(\d+\.\d+\.\d+)") { return $Matches[1] }
    }
    return $null
}
function Get-Latest-Git {
    $r = Get-Json "https://api.github.com/repos/git-for-windows/git/releases/latest"
    if ($r -and $r.tag_name -match "v?(\d+\.\d+\.\d+)") { return $Matches[1] }
    return $null
}
function Get-Latest-Claude {
    $r = Get-Json "https://registry.npmjs.org/@anthropic-ai/claude-code/latest"
    if ($r -and $r.version) { return [string]$r.version }
    return $null
}
function Get-Latest-CCSwitch {
    $r = Get-Json "https://api.github.com/repos/farion1231/cc-switch/releases/latest"
    if ($r -and $r.tag_name -match "v?(\d+\.\d+\.\d+)") { return $Matches[1] }
    return $null
}

function Get-LatestWithPriority {
    param([string]$Name)
    $wingetId = $Fallback[$Name].wingetId
    $v = Get-WingetLatest $wingetId
    if ($v) {
        Write-Info "$Name 最新版（winget）：$v"
        return $v
    }
    $getter = "Get-Latest-" + $Name
    $cmd = Get-Command $getter -ErrorAction SilentlyContinue
    if ($cmd) {
        $v = & $getter
        if ($v) {
            Write-Info "$Name 最新版（官方接口）：$v"
            return $v
        }
    }
    $v = $Fallback[$Name].version
    Write-Warn "$Name 最新版（内置清单）：$v"
    return $v
}

# ---------- 安装后 PATH 刷新 ----------
function Refresh-PythonPath {
    $root = Join-Path $env:LOCALAPPDATA "Programs\Python"
    $verDir = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($verDir) { Ensure-UserPath @($verDir.FullName, (Join-Path $verDir.FullName "Scripts")) }
}
function Refresh-NodePath { Ensure-UserPath @((Join-Path $env:APPDATA "npm"), (Join-Path $env:ProgramFiles "nodejs")) }
function Refresh-GitPath  { Ensure-UserPath @((Join-Path $env:ProgramFiles "Git\cmd")) }

# ---------- 已装版本探测 ----------
function Get-PathVersion {
    param([string[]]$Candidates, [string]$Pattern = "(\d+\.\d+(?:\.\d+)+)")
    foreach ($c in $Candidates) {
        if (Test-Path -LiteralPath $c) {
            try {
                $v = (& $c --version 2>$null | Select-Object -First 1)
                if ($v -and $v -match $Pattern) { return $Matches[1] }
            } catch {}
            try {
                $fv = (Get-Item -LiteralPath $c).VersionInfo.FileVersion
                if ($fv -match $Pattern) { return $Matches[1] }
            } catch {}
        }
    }
    return $null
}

function Get-PythonInstalled {
    $v = Get-CommandVersion -Cmd "python" -Pattern "Python\s+(\d+\.\d+\.\d+)"
    if (-not $v) { $v = Get-CommandVersion -Cmd "py" -Args @("-3", "--version") -Pattern "Python\s+(\d+\.\d+\.\d+)" }
    if (-not $v) {
        $dirs = @()
        foreach ($root in @((Join-Path $env:LOCALAPPDATA "Programs\Python"), (Join-Path $env:ProgramFiles "Python"))) {
            $dirs += Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName "python.exe" }
        }
        $v = Get-PathVersion $dirs -Pattern "Python\s+(\d+\.\d+\.\d+)"
    }
    return $v
}

function Get-NodeInstalled {
    $v = Get-CommandVersion -Cmd "node"
    if (-not $v) { $v = Get-WingetInstalled "OpenJS.NodeJS.LTS" }
    if (-not $v) { $v = Get-PathVersion @((Join-Path $env:ProgramFiles "nodejs\node.exe"), (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe")) }
    return $v
}

function Get-GitInstalled {
    $v = Get-CommandVersion -Cmd "git"
    if (-not $v) { $v = Get-WingetInstalled "Git.Git" }
    if (-not $v) { $v = Get-PathVersion @((Join-Path $env:ProgramFiles "Git\cmd\git.exe"), (Join-Path ${env:ProgramFiles(x86)} "Git\cmd\git.exe")) -Pattern "git version\s+(\d+\.\d+(?:\.\d+)*)" }
    return $v
}

function Get-ClaudeInstalled {
    $v = Get-CommandVersion -Cmd "claude"
    if (-not $v) { $v = Get-WingetInstalled "Anthropic.ClaudeCode" }
    return $v
}
function Get-CCSwitchInstalled {
    $v = Get-CommandVersion -Cmd "cc-switch" -Pattern "(\d+\.\d+\.\d+)"
    if ($v) { return $v }
    $w = Get-WingetInstalled "farion1231.CC-Switch"
    if ($w) { return $w }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\cc-switch\cc-switch.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\CC-Switch\cc-switch.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\cc-switch\CC-Switch.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            try {
                $ver = (Get-Item -LiteralPath $c).VersionInfo.FileVersion
                if ($ver -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
            } catch {}
            return "0.0.0"
        }
    }
    return $null
}

function Get-CCSwitchExe {
    $cmd = Get-Command cc-switch -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\cc-switch\cc-switch.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\CC-Switch\cc-switch.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\cc-switch\CC-Switch.exe")
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

# ---------- 安装动作（winget 优先，官方安装包兜底） ----------
function Install-Python {
    param([string]$Ver)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id "Python.Python.3.14" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { Refresh-PythonPath; return }
        Write-Warn "winget 安装 Python 失败（码 $LASTEXITCODE），改用官方安装器"
    }
    if (-not $Ver) { $Ver = $Fallback["python"].version }
    $tmp = Join-Path $env:TEMP "python-$Ver-amd64.exe"
    Invoke-Download "https://www.python.org/ftp/python/$Ver/python-$Ver-amd64.exe" $tmp
    Start-Process -FilePath $tmp -ArgumentList @("/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0") -Wait
    Refresh-PythonPath
}

function Install-Node {
    param([string]$Ver)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id "OpenJS.NodeJS.LTS" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { Refresh-NodePath; return }
        Write-Warn "winget 安装 Node.js 失败（码 $LASTEXITCODE），改用官方安装器"
    }
    if (-not $Ver) { $Ver = $Fallback["node"].version }
    $tmp = Join-Path $env:TEMP "node-v$Ver-x64.msi"
    Invoke-Download "https://nodejs.org/dist/v$Ver/node-v$Ver-x64.msi" $tmp
    Start-Process msiexec.exe -ArgumentList @("/i", $tmp, "/qn", "/norestart") -Wait
    Refresh-NodePath
}

function Install-Git {
    param([string]$Ver)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id "Git.Git" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { Refresh-GitPath; return }
        Write-Warn "winget 安装 Git 失败（码 $LASTEXITCODE），改用官方安装器"
    }
    if (-not $Ver) { $Ver = $Fallback["git"].version }
    $url = $null
    $r = Get-Json "https://api.github.com/repos/git-for-windows/git/releases/latest"
    if ($r -and $r.assets) {
        $a = $r.assets | Where-Object { $_.name -match "^Git-.*-64-bit\.exe$" } | Select-Object -First 1
        if ($a) { $url = $a.browser_download_url }
    }
    if (-not $url) { $url = $Fallback["git"].url }
    $tmp = Join-Path $env:TEMP "git-$Ver-64-bit.exe"
    Invoke-Download $url $tmp
    Start-Process -FilePath $tmp -ArgumentList @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-") -Wait
    Refresh-GitPath
}

function Install-Claude {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id "Anthropic.ClaudeCode" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { return }
        Write-Warn "winget 安装 Claude Code 失败（码 $LASTEXITCODE），改用 npm"
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm 不可用，无法安装 Claude Code。请先安装 Node.js 后重试。"
    }
    & npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) { throw "npm 安装 Claude Code 失败（码 $LASTEXITCODE）" }
}

function Install-CCSwitch {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id "farion1231.CC-Switch" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { return }
        Write-Warn "winget 安装 cc-switch 失败（码 $LASTEXITCODE），改用官方安装包"
    }
    $asset = $null
    $r = Get-Json "https://api.github.com/repos/farion1231/cc-switch/releases/latest"
    if ($r -and $r.assets) {
        $msi = $r.assets | Where-Object { $_.name -match "Windows.*\.msi$" } | Select-Object -First 1
        if ($msi) { $asset = @{ url = $msi.browser_download_url; kind = "msi" } }
        else {
            $zip = $r.assets | Where-Object { $_.name -match "Windows.*\.zip$" } | Select-Object -First 1
            if ($zip) { $asset = @{ url = $zip.browser_download_url; kind = "zip" } }
        }
    }
    if (-not $asset) {
        $fb = $Fallback["ccswitch"]
        $asset = @{ url = $fb.url; kind = "msi" }
    }
    $tmp = Join-Path $env:TEMP ("cc-switch-" + [IO.Path]::GetFileName($asset.url))
    Invoke-Download $asset.url $tmp
    if ($asset.kind -eq "msi") {
        Start-Process msiexec.exe -ArgumentList @("/i", $tmp, "/qn", "/norestart") -Wait
    } else {
        $dest = Join-Path $env:LOCALAPPDATA "Programs\cc-switch"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Expand-Archive -LiteralPath $tmp -DestinationPath $dest -Force
        Ensure-UserPath @($dest)
    }
}

# ---------- 核心：检测 + 决策 ----------
function Ensure-Tool {
    param(
        [string]$Name,
        [string]$DisplayName,
        [scriptblock]$InstalledGetter,
        [scriptblock]$InstallAction
    )
    Write-Head "检查 $DisplayName"
    $installed = & $InstalledGetter
    $latest = Get-LatestWithPriority $Name
    $script:LatestVersions[$Name] = $latest

    if ($installed) { Write-Info "已安装版本：$installed" } else { Write-Info "未安装" }
    if ($latest) { Write-Info "最新版本：$latest" } else { Write-Warn "无法获取最新版本，按已装状态处理" }

    if ($CheckOnly) {
        if ($installed) {
            if ($latest -and (Compare-Version $installed $latest) -lt 0) {
                Write-Warn "有可用更新：$installed -> $latest"
            } else {
                Write-OK "已是最新"
            }
        } else {
            Write-Warn "未安装（最新 $latest）"
        }
        return
    }

    $needInstall = $false
    if (-not $installed) {
        $needInstall = $true
    } elseif ($latest -and (Compare-Version $installed $latest) -lt 0) {
        if ($Update) {
            Write-Warn "检测到旧版本 $installed，-Update 已指定，升级到 $latest"
            $needInstall = $true
        } else {
            $ans = Read-Host "当前版本 $installed，最新 $latest。是否升级？(Y/N)"
            if ($ans -match "^[yY]") { $needInstall = $true }
        }
    }

    if ($needInstall) {
        Write-Host "    正在安装/升级 $DisplayName，请稍候..."
        & $InstallAction $latest
        Write-OK "$DisplayName 安装完成"
    } else {
        Write-OK "无需操作"
    }
}

# ---------- 主流程 ----------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   AI 学习工作流 · 环境配置" -ForegroundColor Cyan
if ($CheckOnly) { Write-Host "   （检测模式：只检查，不安装）" -ForegroundColor Yellow }
Write-Host "============================================" -ForegroundColor Cyan

$script:LatestVersions = @{}

Ensure-Tool "python" "Python" `
    { Get-PythonInstalled } `
    { Install-Python }

Ensure-Tool "node" "Node.js" `
    { Get-NodeInstalled } `
    { Install-Node }

Ensure-Tool "git" "Git for Windows" `
    { Get-GitInstalled } `
    { Install-Git }

if (-not $SkipClaude) {
    Ensure-Tool "claude" "Claude Code" `
        { Get-ClaudeInstalled } `
        { Install-Claude }
} else {
    Write-Warn "已跳过 Claude Code（-SkipClaude）"
}

Ensure-Tool "ccswitch" "cc-switch" `
    { Get-CCSwitchInstalled } `
    { Install-CCSwitch }

# ---------- 收尾 ----------
Write-Head "收尾"
if ($CheckOnly) {
    Write-Host "检测完成。以上为各工具的版本状态。"
    exit 0
}

$cc = Get-CCSwitchExe
if ($cc) {
    Write-Host "正在打开 cc-switch ..."
    Start-Process -FilePath $cc
} else {
    Write-Warn "未找到 cc-switch，请从开始菜单手动打开。"
}

Write-Host ""
Write-Host "================ 下一步 ================" -ForegroundColor Green
Write-Host "1) 在 cc-switch 中点击「添加供应商」"
Write-Host "2) 选择或填写 Base URL，粘贴你的 API Key"
Write-Host "3) 切换到该供应商（自动写入 Claude Code 配置）"
Write-Host "4) 打开 Obsidian，Claudian 后端选择 Claude Code 即可使用"
Write-Host "========================================" -ForegroundColor Green
