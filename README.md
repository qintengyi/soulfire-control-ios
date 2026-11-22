# SoulFire Control (iOS)

一个用于远程控制 [SoulFireMC](https://soulfiremc.com/) dedicated server 的 iOS 控制端 App。
走官方 REST HTTP API（OpenAPI 2.11.0）+ Bearer JWT 鉴权，不依赖 gRPC-Web / protobuf。

## 功能

- **实例管理** — 列出/创建/删除实例，查看每个实例的 bot 概要（在线/目标/失败数）
- **Bot 控制台** — 列出 bot、批量启停/重启、单个 bot 详情控制台：
  - 十字方向键移动控制（前/后/左/右/跳/潜行/疾跑，按下生效、松开停止）
  - 发送聊天 / 执行 SoulFire 命令
  - 重生、飞行、快捷启停
  - 背包网格查看 + 点击槽位
  - 实时状态：坐标、朝向、生命、饥饿、经验、游戏模式、维度
- **账号管理** — 批量添加离线（OFFLINE）Java 账号，自动计算 offline UUID；删除账号
- **代理管理** — 单个添加 / 批量导入（支持 `socks5://user:pass@host:port` 格式）/ 删除
- **日志查看** — 全局日志或当前实例日志切换，自动 3 秒刷新，带级别着色和搜索
- **指标监控** — 实例指标（在线 bot、发包速率、流量、tick、平均生命）+ 服务器指标（CPU、堆内存、线程、运行时长）

## 技术栈

- SwiftUI + `@Observable`（iOS 18+ Observation 框架）
- `URLSession` + Bearer Token
- Keychain 存储 Token，UserDefaults 存储服务器地址
- XcodeGen（`project.yml` 生成 `.xcodeproj`）
- Minecraft 风格深色主题（红石红/火焰橙/钻石青）

## 本地开发

需要 macOS + Xcode 16.2+。

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open SoulFireControl.xcodeproj
```

在 Xcode 中选目标设备 → Run。首次启动填入服务器地址、端口（默认 38765）和 API Token。

> Token 在 SoulFire 服务器终端执行 `generate-token api` 生成。

## GitHub Actions 云编译打包

推送代码到 `main` 分支或打 `v*` tag 会自动触发构建，产出 IPA 上传为 artifact。

### 签名模式（自动判断）

workflow 会检查 repo secrets 是否配置了签名材料，自动选择模式：

- **未签名模式**（默认）：产出未签名 `.ipa`，下载后用 [全能签](https://sign.crxxn.com/) / [Sideloadly](https://sideloadly.io/) 本地重签安装
- **签名模式**：当以下 3 个 secrets 都配置后自动启用，产出 ad-hoc 签名可直接安装的 IPA

### 配置签名 secrets（可选，用于自动签名）

在你的 GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret，添加：

| Secret 名 | 值 | 说明 |
|---|---|---|
| `IOS_P12_BASE64` | p12 证书文件的 base64 编码 | `base64 -i certificate.p12` 的输出 |
| `IOS_P12_PASSWORD` | p12 导出密码 | |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` 文件的 base64 编码 | `base64 -i profile.mobileprovision` 的输出 |

> 描述文件（provisioning profile）的 bundle ID 必须匹配 `com.soulfire.control`，且包含你设备的 UDID。

生成 base64 的命令：

```bash
base64 -i your_cert.p12 | pbcopy
base64 -i your_profile.mobileprovision | pbcopy
```

### 手动触发构建

在仓库 Actions 页 → "Build iOS IPA" → Run workflow，可勾选 "强制签名构建" 测试签名流程。

## 目录结构

```
soulfire-control-ios/
├── project.yml                          # XcodeGen 配置
├── .github/workflows/build.yml          # 云编译 workflow
└── SoulFireControl/
    ├── Sources/
    │   ├── App/                         # 入口 + 主题
    │   ├── Models/                      # Codable 数据模型 + 辅助
    │   ├── Networking/                  # APIClient + Keychain + API 门面
    │   ├── ViewModels/                  # @Observable VM
    │   └── Views/                       # SwiftUI 视图
    │       ├── Components/              # 通用组件
    │       ├── Instances/               # 实例列表
    │       ├── Bots/                    # Bot 列表 + 详情控制台
    │       ├── Accounts/                # 账号管理
    │       ├── Proxies/                 # 代理管理
    │       ├── Logs/                    # 日志
    │       ├── Metrics/                 # 指标
    │       └── Settings/                # 服务器配置 + 设置
    └── Resources/
        └── Assets.xcassets/             # 图标 + 启动色
```

## API 契约

基于 SoulFire OpenAPI schema `2.11.0`，覆盖以下服务：
`InstanceService` / `BotService` / `BotLiveService` / `InventoryService` / `ChatService` / `CommandService` / `ClientService` / `LogsService` / `MetricsService` / `InstanceService`（账号/代理子资源）。

完整 schema 见 [SoulFire HTTP API 文档](https://soulfiremc.com/docs/openapi)。

## License

遵循 SoulFire 上游 AGPL-3.0。
