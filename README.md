# AI 学习工作流

一套把「厚教材 → 能真正学会」的固定流程，封装成可一键复现的 Obsidian 库：
拆书 → 五级水平拆解 → 二八定律学习计划 → 十问测试 → 一页速查表。

这个仓库是**模板 + 一键安装器**：任何一台 Windows 电脑从 Release 下载
一个引导器（或克隆后运行 `install.ps1`），就会生成一个功能完全一致的
「AI 学习工作流」Obsidian 库，无需手动配路径、装插件、写启动器。

> 个人学习笔记（`03-学习主题/*`、`04-教材分块/*`、API 密钥、会话记录）
> 默认不会进入本仓库，也不会被安装脚本带入新库。

---

## 一键安装（Windows 10 / 11）

### 推荐方式：Release 单文件引导器

不用克隆仓库、不用手动解压。到本仓库的 **Releases** 页面下载最新的
`HelpToStudy-QuickInstall.bat`，双击运行即可。它会自动完成：

1. 从 Release 下载库压缩包并解压到临时目录
2. 检测/安装环境：**Obsidian、Python、Node.js、Git for Windows、
   Claude Code、cc-switch**（已装的最新版直接跳过；缺失的自动安装，
   版本来源优先级 winget > 官方接口 > 内置清单）
3. 安装「AI 学习工作流」Obsidian 库（默认
   `%USERPROFILE%\ObsidianVaults\AI学习工作流`；会弹出文件夹选择框，
   可自选位置，点「取消」则询问是否用默认位置）
4. 装完自动用 Obsidian 打开库

> 浏览器若提示「不常见下载」，点击**保留 / 仍要运行**即可（脚本未签名，
> 内容全部开源，可在仓库里直接审阅）。
> 不需要自动装环境时，可用 `-SkipEnv` 只装库，参数见下表。

#### 常用参数

在 cmd / PowerShell 中追加参数运行：

```powershell
.\HelpToStudy-QuickInstall.bat -VaultPath "D:\我的资料\AI学习工作流"
.\HelpToStudy-QuickInstall.bat -SkipEnv
.\HelpToStudy-QuickInstall.bat -SkipMineru -NoOpenObsidian
```

| 参数 | 作用 |
| --- | --- |
| `-SkipEnv` | 跳过环境检测/安装，只装库 |
| `-SkipClaude` | 跳过 Claude Code 安装 |
| `-VaultPath "路径"` | 指定库安装位置 |
| `-NoDialog` | 不弹文件夹选择框，用默认位置 |
| `-SkipPython` | 跳过 Python 虚拟环境与拆书依赖 |
| `-SkipMineru` | 不装 MinerU 云端 OCR 工具 |
| `-NoOpenObsidian` | 装完不自动打开 Obsidian |
| `-Force` | 目标目录已存在时不询问，直接继续 |

### 备用方式：手动 ZIP 或克隆

如果浏览器拦截下载、想离线安装，或想先看看内容再装：

1. 到 **Releases** 下载 `HelpToStudy-Vault-<版本>.zip`（或克隆本仓库）
2. 解压后先双击「**环境配置.bat**」，检测/安装环境
   （`环境配置.bat -CheckOnly` 只查不装；`环境配置.bat -SkipClaude`
   跳过 Claude Code；装完会自动打开 cc-switch 供粘贴 API Key）
3. 再双击「**安装.bat**」按提示安装（效果等同手动运行 `.\install.ps1`）

> 「安装.bat」会自动以「绕过执行策略」的方式启动 install.ps1，
> 只对本次生效、不修改系统设置，因此下载/解压的仓库也能直接双击安装。

### 装完之后的设置

1. 首次打开若提示「信任社区插件」，选**信任**（插件文件已随库装好，
   包含 Copilot、Dataview、QuickAdd、Templater、Claudian、Excalidraw CN）。
2. 打开右侧边栏的 **Claudian**，在设置中选择后端（本机 Codex 或 Claude Code）。
3. 大部分中英意文书都可以：双击 `_工具\设置MinerU令牌.bat`，
   粘贴 [MinerU](https://mineru.net) 的免费 Token。
4. 打开 `00-使用指南\📖 使用说明.md`，开始你的第一个学习主题。

---

## 这个库能做什么

| 命令 / 工具 | 用途 |
| --- | --- |
| `_工具\拆书.bat` | 把 PDF / EPUB / Word 教材按章节拆成"一章一个文件" |
| `_工具\拆书-MinerU.bat` | 扫描版/数学书：MinerU 云端解析（公式转 LaTeX）+ 按章拆分 |
| `/拆书` | 让 AI 判断用哪种方式并执行（Claudian 中触发） |
| `/新主题-拆解与计划` | 五级水平拆解 + 二八定律 10 次学习计划，一键写入笔记 |
| `/学案` | 每章生成学案 + Session 记录 |
| `/测试我` | 十问考官测试，记录分数和薄弱点 |
| `/速查表` | 生成一页速查表（开课前 5 分钟复习） |
| `/更新进度` | 自动更新主题主页的进度/级别/薄弱点 |

核心原则：**笔记就是记忆**。进度永远写在笔记里（frontmatter + 固定标记区），
AI 只负责读写，不把整个库塞进对话，因此省钱、可长期使用。

### 拆书引擎能力

- 章节识别支持中/英/意/西/法常见标题，包括意大利语序数词课名
  （`Prima lezione`、`Seconda lezione` … `Sedicesima lezione`），
  目录页码 `(1)` 格式也能正确识别；
- 生成的章节笔记里图片统一使用 Obsidian 原生嵌入 `![[图片名]]`，
  按文件名全库解析，不受书文件夹名里的括号/逗号等特殊字符影响，
  Obsidian 中必定能显示；
- OCR 漏掉章节标题时，可用 `--opener-pattern` 补充定位，例如每课都以
  `## I. Impariamo a parlare` 开头的教材：

  ```powershell
  python _工具/split_textbook.py "<书>\00-MinerU解析全文.md" --out "04-教材分块" --split-mode chapter --opener-pattern "Impariamo a parlare"
  ```

---

## 目录结构

```
AI学习工作流/
├── 00-使用指南/        首页、使用说明
├── 01-提示词库/        Step1-5 提示词原文（含合并版）
├── 02-模板/            新主题、Session 记录、速查表模板
├── 03-学习主题/        每个主题一个文件夹（主页/计划/测试/速查表）
├── 04-教材分块/        拆书结果（00-教材信息、00-目录、01-全书大纲、章节分块）
├── _工具/              拆书脚本 + 相对路径启动器 + requirements.txt + .venv（可选）
├── copilot/            Copilot 插件自定义提示词
├── .claude/commands/   Claudian 斜杠命令（输入 / 触发）
└── .obsidian/          插件与配置（随库装好）
```

## 隐私说明（重要）

- `.gitignore` 已排除：个人学习主题、拆书内容、备份、插件 `data.json`
  （可能含 API 密钥）、会话记录、Token 文件。
- 安装时不会复制原电脑上的任何个人笔记与密钥，只复制工作流本身。
- 如果希望把个人笔记也同步到 GitHub，请自行调整 `.gitignore`，并**确保
  `data.json` 和 Token 文件仍被排除**。

## 常见问题

**Q：引导器下载失败 / 离线环境怎么装？**
A：直接到 Releases 下载 `HelpToStudy-Vault-<版本>.zip`，解压后手动运行
「环境配置.bat」→「安装.bat」，效果与一键安装相同。

**Q：下载 .bat 时浏览器提示「不常见下载」？**
A：点击**保留 / 仍要运行**即可。引导器只做下载、解压和调用仓库里的开源脚本，
不修改系统设置，不放任何可疑内容。

**Q：装过旧版本，怎么升级？**
A：再次运行一键引导器（或解压新版 ZIP 后运行「安装.bat」）。目标目录已存在时
会询问是否继续，个人笔记保留，只覆盖/补充工作流文件。

**Q：装完打开 Obsidian 没有 Claudian 图标？**
A：确认 `.obsidian/community-plugins.json` 已复制且首次打开时选择了「信任」。
如果插件未加载，可在设置 → 第三方插件中手动启用。

**Q：Claudian 提示找不到 Codex / Claude？**
A：需要先安装 Codex CLI 或 Claude Code，并在 Claudian 设置里选择后端。
如果用的是 Codex 桌面版，Claudian 会自动发现本机的 codex 命令。

**Q：拆书报「找不到 MinerU 命令行工具」？**
A：安装时已自动执行 `pip install mineru-open-api`（可用 `-SkipMineru` 跳过）。
手动补救：运行 `_工具\.venv\Scripts\pip.exe install mineru-open-api`。

**Q：`install.ps1` 双击没反应 / 提示"禁止运行脚本"？**
A：直接双击仓库根目录的「安装.bat」即可，它已内置绕过执行策略的启动方式；
不需要修改系统设置。手动运行时用
`powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1`。

**Q：安装时可以自己选库的位置吗？**
A：可以。双击「安装.bat」后先弹出「选择文件夹」对话框，选中哪个文件夹，
库就装到哪；点「取消」可用默认位置或退出。想跳过对话框直接用默认位置，
运行 `.\install.ps1 -NoDialog`；想指定固定位置，运行
`.\install.ps1 -VaultPath "D:\我的资料\AI学习工作流"`。

**Q：macOS / Linux 能用吗？**
A：当前一键安装器面向 Windows（.bat 启动器 + PowerShell）。
拆书脚本 `split_textbook.py` 本身跨平台，可在任意系统手动运行。

## 从零开始维护

改了什么想同步回仓库？直接在仓库里改，然后：

```powershell
git add -A
git commit -m "更新说明"
git push
```

想在新电脑上再装一次：重复上面的「一键安装」步骤即可。

### 发布新版本

打 tag 并推送，GitHub Actions 会自动构建发布包并生成 Release：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

也可以在本地生成资产后手动发布（Actions 不可用时的兜底）：

```powershell
.\scripts\build-release.ps1 -Tag v1.0.0 -Repo xiaomaogou66/HelpToStudy -OutDir .\dist
```

会生成 `HelpToStudy-Vault-<版本>.zip`、`HelpToStudy-QuickInstall.bat` 和
`release-notes.md`；手动发布时把前两个文件作为 Release 资产上传即可。

### 库可以随便拷贝、移动

`_工具` 里的拆书启动器全部使用**相对路径**（自动定位库目录、虚拟环境和
Token 文件），不依赖任何本机绝对路径。因此整个库文件夹可以拷贝到 U 盘、
换电脑、移动位置，双击 `_工具\拆书.bat` 依然能用；缺 Python 或依赖时
启动器会给出明确提示，不会像以前一样报"找不到路径"。
