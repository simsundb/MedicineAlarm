# 吃药提醒（MedicineAlarm）

macOS 原生菜单栏吃药提醒应用。到点弹出置顶窗口 + 循环响铃 + 语音播报，
必须手动点「已服用」或「稍后提醒」才会消失。

针对本机环境：**Apple Silicon (M1) / macOS 26**，只用 Command Line Tools 构建，
不需要装完整 Xcode。

---

## 功能

- **7 个每日闹钟**（可在界面里增删改）：08:00 激素服药 / 09:00 排异服药 /
  12:00 服药提醒 / 15:00 排异服药 / 18:00 服药 / 20:00 晚餐后服药 / 21:00 睡前
- **到点弹窗**：居中、置顶（`screenSaver` 层级）、跟随当前桌面、能盖在全屏应用上；
  循环响铃（默认每 5 秒一次，可调）+ 每 25 秒中文语音播报「该吃药了，×××」
- **必须人工关闭**：只有「已服用」「稍后 5 分钟」「稍后 10 分钟」三个出口，
  窗口没有关闭按钮，点红叉也关不掉
- **快捷键**：`Enter` = 已服用，`Esc` = 稍后 5 分钟
- **服药记录**：每次操作都落盘，按天倒序可查，带「今天已服用 N/M 次」进度环
- **补服逻辑**：电脑睡醒后，补服窗口内错过的闹钟会补弹（标注「补服提醒 · 原定 XX:XX」）；
  超过窗口只记一笔「已错过」，不会一次性砸一堆过期弹窗。窗口默认 2 小时，可在设置里调
- **暂停提醒**：可暂停 1 小时 / 4 小时 / 到当天结束
- **免打扰日**：勾选周一~周日里的任意几天，那几天完全不弹窗、也不记「已错过」
- **设置窗口**：语音播报、提示音、补服窗口、免打扰日、开机自启都收在这里（详见「设置」一节）
- **主菜单栏**：标准的应用 / 编辑 / 窗口菜单，文本框的 `⌘C` / `⌘V` 能用了，`⌘,` 开设置
- **菜单栏状态**：图标旁边显示下一个闹钟时间，暂停时显示「暂停」、免打扰日显示「免打扰」
- **开机自启**：走系统标准的登录项（系统设置 › 通用 › 登录项 里能看到）

---

## 设置

两个入口，等价：

- 鼠标点菜单栏 💊 图标 → 下拉菜单里的「设置…」
- 应用激活时按 `⌘,`（标准主菜单栏里也有一份）

| 设置项 | 可选值 | 默认 |
|---|---|---|
| 语音播报 | 开 / 关 | 开 |
| 提示音 | 14 个系统音效（见下），带「试听」按钮 | `Glass` |
| 提示音间隔 | 2–30 秒 | 5 秒 |
| 免打扰日 | 周一~周日，任意多选 | 不选（每天都提醒） |
| 补服窗口 | 30 分钟 / 1 / 2 / 4 / 8 小时 | 2 小时 |
| 开机自动启动 | 开 / 关 | 关 |
| 在访达中显示闹钟配置文件 | — | — |

**提示音**都取自 `/System/Library/Sounds`，不用往 bundle 里塞音频文件：
`Glass` / `Ping` / `Submarine` / `Hero` / `Morse` / `Pop` / `Purr` /
`Sosumi` / `Tink` / `Basso` / `Blow` / `Bottle` / `Frog` / `Funk`。
「试听」走独立实例，不会打断正在循环的提醒。提示音间隔改完，下一次提醒就生效。

**免打扰日**是为「周末 / 休息日不开电脑」准备的：勾上的那几天，
调度器直接静默吞掉到点的闹钟——不弹窗，也不在服药记录里记「已错过」，
免得周一回来看到一屏假的漏服。菜单栏文字会变成「免打扰」。

> ⚠️ 免打扰是**按星期几**，不是按日期。中国的法定节假日和调休由国务院逐年公告，
> 没有任何系统 API 能算出来，写死在代码里明年就过期；星期几才是稳定可算的。
> 所以调休把周末变成工作日的那几天，仍然不会提醒——那几天请手动取消勾选。

菜单栏下拉菜单里的「语音播报」和「开机自动启动」跟设置窗口里的是同一份开关，
两处改哪边都一样。

---

## 构建与安装

```bash
./build_app.sh              # 编译 + 打包 + 签名 + 安装到 ~/Applications + 启动
./build_app.sh --no-install # 只编译打包，产物在 build/MedicineAlarm.app
./build_app.sh --no-launch  # 安装但不自动启动
```

想装到 `/Applications`：`INSTALL_DIR=/Applications ./build_app.sh`

脚本会依次做这些事：`swift build -c release` → 用 Core Graphics 生成图标 →
组装 `.app`（写 `Info.plist`、`PkgInfo`）→ **ad-hoc 签名** → `lsregister` 注册 → `open` 启动。

本机没有 Developer ID（`security find-identity` 返回 0 个身份），所以只能用 ad-hoc 签名。
够本机运行；代价是不能公证，拷给别人需要对方先 `xattr -rd com.apple.quarantine` 才能打开。

---

## 数据在哪

| 内容 | 路径 |
|---|---|
| 闹钟配置 | `~/Library/Application Support/MedicineAlarm/alarms.json` |
| 服药流水 | `~/Library/Application Support/MedicineAlarm/history.json`（保留最近 180 天）|
| 偏好设置 | `UserDefaults`，域 `com.sunzh.medicine-alarm`（免打扰日、提示音、补服窗口等都在这）|

想直接看 / 改偏好：`defaults read com.sunzh.medicine-alarm`，
或者从设置窗口底部的「在访达中显示」跳到闹钟配置文件。

首次启动时，如果发现旧版 Python 程序的配置 `~/.medicine_alarm/config.json`，
会自动把那 7 个闹钟和名称导入过来。

---

## 排查问题

应用是菜单栏常驻（`LSUIElement`），没有 Dock 图标；退出走菜单栏的「退出」或 `⌘Q`。
`⌘,` 随时打开设置窗口。

**看日志**：`NSLog` 会打出调度器心跳和每次触发原因。

```bash
# 用 Console.app 过滤进程 MedicineAlarm 最方便
log show --last 10m --predicate 'process == "MedicineAlarm"' --style compact
```

想确认调度循环是否还活着，日志里应该每 30 秒出现一行
`[MedicineAlarm] 心跳 HH:mm:ss｜闹钟 7 个｜静默中 false`。
`静默中` 为 `true` 表示当前处于暂停中，或者今天是免打扰日——这时候不弹窗是正常的。

**自检**（跑一遍关键路径后自动退出，会弹一个测试提醒）：

```bash
"/Users/sunzh.mac/Applications/吃药提醒.app/Contents/MacOS/MedicineAlarm" --self-test
```

**开机自启**：

```bash
"…/MedicineAlarm" --login-item-status          # 查状态
"…/MedicineAlarm" --set-login-item on|off       # 开关
```

> ⚠️ 上面这些命令行方式会**绕过 LaunchServices**。它们对闹钟功能没影响，
> 但**不要**用这种方式去测试系统通知权限——绕过 LaunchServices 启动
> 会让系统直接把这台机器上的应用标记为「通知被拒绝」，且不会再弹授权框。
> 日常排查进程起不来，请用 `log show`，或者 `open "/Users/…/吃药提醒.app"`。

---

## 已知限制

- **应用必须处于运行状态**才会响（已设开机自启 + 常驻菜单栏）。从菜单栏「退出」后就不会再提醒。
- 电脑**完全关机**期间的闹钟不会响，开机后超出补服窗口（默认 2 小时）的只会记为「已错过」。
- 免打扰日**按星期几**判定，不认法定节假日和调休（没有可用的系统 API）。调休上班的周末
  仍然不会提醒，那天需要手动取消勾选。
- 应用未运行期间经过的闹钟**不会**在启动时回溯弹出，也不会凭空记账——
  没观察到的时间段不该编造记录。想看缺口请查「服药记录」。
- 系统进入**安全输入模式**（比如聚焦在密码框）时，任何应用都无法抢焦点，
  这是 macOS 的限制，此时弹窗可能出现但不会自动置前。

---

## 代码结构

```
Sources/MedicineAlarm/
├── main.swift                    入口；另含 --self-test / --set-login-item 命令行分支
├── App/
│   ├── AppDelegate.swift         组装各部件、生命周期
│   ├── MainMenu.swift            主菜单栏（编辑菜单的 ⌘C/⌘V + 「设置…」的 ⌘,）
│   └── SelfTest.swift            自检模式
├── Models/
│   ├── Alarm.swift               闹钟数据结构 + 出厂默认 7 个
│   ├── AlarmStore.swift          闹钟的读写与增删改
│   └── DoseLog.swift             服药流水
├── Core/
│   ├── Preferences.swift         所有 UserDefaults 偏好的唯一入口
│   ├── Scheduler.swift           每秒检查、到点判定、补服窗口、稍后提醒、暂停、免打扰日
│   ├── AlarmSound.swift          循环提示音 + 中文语音播报 + 设置里的试听
│   └── LoginItem.swift           开机自启（SMAppService，失败回退 LaunchAgent）
└── UI/
    ├── Theme.swift               设计令牌：颜色/间距/圆角/字号/按钮样式
    ├── Components.swift          进度环、状态标签、圆底图标
    ├── PopupController.swift     置顶弹窗的创建与队列
    ├── PopupView.swift           提醒弹窗界面
    ├── StatusBarController.swift 菜单栏图标与菜单
    ├── SettingsWindowController.swift / SettingsView.swift   设置窗口
    ├── MainWindowController.swift / AlarmListView.swift / AlarmEditView.swift
    └── HistoryWindowController.swift / HistoryView.swift
```

界面颜色全部走 `Theme.swift` 里的语义令牌，深浅色自动适配，文字对比度均 ≥ 4.5:1。

界面之外，**所有 `UserDefaults` 键都收敛在 `Core/Preferences.swift`**（单例 `Preferences.shared`，
是一个 `ObservableObject`，改设置后菜单栏文字会立刻跟着刷新）。
之前 `"speakEnabled"` 这类键名字符串在几个文件里各写一遍，加一个设置项要改四处。

---

## 旧版 Python 版本

原来的 `~/Downloads/06.ai/05.claude/medicine_alarm.py` 用的是 tkinter，
它的开机自启项一直处于「已加载但每次启动都失败」的状态（退出码 2）。

`./retire_legacy.sh` 会把旧文件备份到本项目的 `.backup/` 并卸载那个自启项。
**原文件不删除**，仍在 `~/Downloads/06.ai/05.claude/` 和 `~/.medicine_alarm/`。
