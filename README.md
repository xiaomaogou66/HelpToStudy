# AI 学习工作流

一套把「厚教材 → 能真正学会」的固定流程，封装成可一键复现的 Obsidian 库：
拆书 → 五级水平拆解 → 二八定律学习计划 → 十问测试 → 一页速查表。

这个仓库是**模板 + 一键安装器**：任何一台 Windows 电脑克隆后运行
`install.ps1`，就会生成一个功能完全一致的「AI 学习工作流」Obsidian 库，
无需手动配路径、装插件、写启动器。

> 个人学习笔记（`03-学习主题/*`、`04-教材分块/*`、API 密钥、会话记录）
> 默认不会进入本仓库，也不会被安装脚本带入新库。

---

## 一键安装（Windows）

### 前置条件

| 软件 | 说明 |
| --- | --- |
| Obsidian | 必需。从 https://obsidian.md 下载 |
| Python 3.10+ | 拆书工具需要。安装时勾选「Add Python to PATH」 |
| Codex CLI 或 Claude Code | Claudian 的 AI 后端，二选一安装即可 |

### 步骤

1. 克隆仓库（或用 GitHub 的 Download ZIP）：

   ```powershell
   git clone https://github.com/<你的用户名>/ai-learning-workflow.git
   cd ai-learning-workflow
   ```

2. 在仓库根目录的 PowerShell 中运行：

   ```powershell
   .\install.ps1
   ```

   默认安装到 `%USERPROFILE%\ObsidianVaults\AI学习工作流`。
   常用参数：

   ```powershell
   .\install.ps1 -VaultPath "D:\我的资料\AI学习工作流"   # 自定义位置
   .\install.ps1 -OpenObsidian                            # 装完直接打开
   .\install.ps1 -SkipMineru                              # 不需要扫描版 OCR 时
   ```

   安装脚本会自动完成：创建目录结构 → 复制模板/提示词/命令/配置 →
   创建 Python 虚拟环境并安装拆书依赖 → 生成带本机路径的 `_工具/*.bat` 启动器。

3. 用 Obsidian 打开安装好的库文件夹。

   - 首次打开若提示「信任社区插件」，选**信任**（插件文件已随库装好，
     包含 Copilot、Dataview、QuickAdd、Templater、Claudian、Excalidraw CN）。
   - 打开右侧边栏的 **Claudian**，在设置中选择后端（本机 Codex 或 Claude Code）。

4. 只有扫描版/数学书才需要：双击 `_工具\设置MinerU令牌.bat`，
   粘贴 [MinerU](https://mineru.net) 的免费 Token（每日 1000 页）。

5. 打开 `00-使用指南\📖 使用说明.md`，开始你的第一个学习主题。

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

---

## 目录结构

```
AI学习工作流/
├── 00-使用指南/        首页、使用说明
├── 01-提示词库/        Step1-5 提示词原文（含合并版）
├── 02-模板/            新主题、Session 记录、速查表模板
├── 03-学习主题/        每个主题一个文件夹（主页/计划/测试/速查表）
├── 04-教材分块/        拆书结果（00-教材信息、00-目录、01-全书大纲、章节分块）
├── _工具/              split_textbook.py + 生成的 .bat 启动器 + .venv
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

**Q：装完打开 Obsidian 没有 Claudian 图标？**
A：确认 `.obsidian/community-plugins.json` 已复制且首次打开时选择了「信任」。
如果插件未加载，可在设置 → 第三方插件中手动启用。

**Q：Claudian 提示找不到 Codex / Claude？**
A：需要先安装 Codex CLI 或 Claude Code，并在 Claudian 设置里选择后端。
如果用的是 Codex 桌面版，Claudian 会自动发现本机的 codex 命令。

**Q：拆书报「找不到 MinerU 命令行工具」？**
A：安装时已自动执行 `pip install mineru-open-api`（可用 `-SkipMineru` 跳过）。
手动补救：运行 `_工具\.venv\Scripts\pip.exe install mineru-open-api`。

**Q：`install.ps1` 双击没反应？**
A：PowerShell 默认禁止运行脚本。请在仓库目录打开 PowerShell，执行
`Set-ExecutionPolicy -Scope Process Bypass` 后再运行 `.\install.ps1`。

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
