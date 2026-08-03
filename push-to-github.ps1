#Requires -Version 5.1
<#
.SYNOPSIS
    把本仓库推送到你的 GitHub（首次使用）
.DESCRIPTION
    优先使用 GitHub CLI（gh）创建仓库并推送；
    未安装 gh 时改用 git push（首次会弹出 GitHub 登录窗口）。
.PARAMETER RepoName
    仓库名（默认 ai-learning-workflow）
.PARAMETER Visibility
    仓库可见性：private（默认）/ public
.PARAMETER Description
    仓库描述
.EXAMPLE
    .\push-to-github.ps1 -RepoName ai-learning-workflow -Visibility private
#>
param(
    [string]$RepoName = "ai-learning-workflow",
    [ValidateSet("public", "private")][string]$Visibility = "private",
    [string]$Description = "AI 学习工作流：可一键复现的 Obsidian + AI 学习流程（拆书 / 五级拆解 / 二八计划 / 十问测试 / 速查表）"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    & gh repo create $RepoName "--$Visibility" --source . --remote origin --push --description $Description
    if ($LASTEXITCODE -ne 0) {
        throw "创建仓库失败。请先运行 gh auth login 登录 GitHub，然后重试。"
    }
    $who = (gh api user --jq .login).Trim()
    Write-Host "已完成！仓库地址：https://github.com/$who/$RepoName" -ForegroundColor Green
} else {
    Write-Host "未检测到 GitHub CLI (gh)。改用 git push，首次会弹出 GitHub 登录窗口。"
    $user = Read-Host "请输入你的 GitHub 用户名"
    if (-not $user) { throw "未输入用户名" }
    $url = "https://github.com/$user/$RepoName.git"
    & git remote remove origin 2>$null
    & git remote add origin $url
    & git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        throw "推送失败。请确认用户名正确、网络可用，并已在弹出的窗口中完成 GitHub 登录。"
    }
    Write-Host "已完成！仓库地址：https://github.com/$user/$RepoName" -ForegroundColor Green
    Write-Host "提示：若想把仓库设为 private，请到 GitHub 仓库页面 Settings -> General 修改可见性。"
}
