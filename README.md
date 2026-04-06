# Helios

Helios 是一个建立在 Vapor 之上的轻量后端框架骨架，目标是服务于：

- 中小型网站
- API 服务
- 长期运行在 Linux 上的 Swift 服务端应用

当前设计重点不是“大而全”，而是：

- **精简可用**
- **容易继续长大**
- **保留清晰的扩展点与演进边界**

如果用一句话概括当前状态：

> Helios 现在已经从“个人风格的 Vapor 骨架”，推进到了“有测试、有 CI、有 typed config、有 staged setup、也有双轨扩展点 API 的轻量框架雏形”。

---

## 当前已经完成的主线能力

基于当前主线，Helios 已经具备这些能力：

### 1. 应用主入口与 staged setup
- `HeliosApp`
  - 负责创建 `Application`
  - 读取配置
  - 以分阶段方式装配：
    - server
    - storage
    - views
    - middleware
    - routes
    - background jobs

### 2. Typed config + fail-fast
- `HeliosConfig`
- `HeliosConfigLoader`
- `HeliosAppConfig`

当前配置系统已经支持：
- typed config model
- `base.json -> <env>.json -> environment variables` 三层加载
- 启动阶段 fail-fast validation

### 3. 扩展点主线
- `HeliosHandler`
- `HeliosFilter`
- `HeliosTask`
- `HeliosTimer`
- `HeliosModel`
- `HeliosAppDelegate`

当前扩展点已经支持：
- context-aware 构造（Task / Timer / Handler / Filter）
- descriptor/provider 新接口
- legacy builder API 兼容保留
- descriptor-first, fallback-to-legacy 的双轨过渡

### 4. Registrar 收口
当前 route / filter / model 的主线注册逻辑已经开始从总入口收出来，框架边界比最早清楚很多。

### 5. 测试脚手架
Helios 已经有第一版测试脚手架：
- smoke tests
- integration tests
- context-aware tests
- descriptor tests
- fixture / harness

并且当前测试设计仍然坚持：
- **零外部依赖**
- 可本地直接跑

### 6. CI baseline
Helios 已经接入第一版 GitHub Actions CI，当前主线目标是提供：
- lint
- build
- test

---

## 项目状态：现在处于什么阶段

Helios 现在已经不是纯计划阶段，也不是只停留在“拆 issue”。

已经完成并进主线的关键工作包括：
- README 第一版
- 测试脚手架 baseline
- typed config / fail-fast
- `HeliosApp.setup()` 分阶段收口
- Task / Timer context-aware 构造
- Handler / Filter context-aware 构造
- descriptor/provider 双轨 API
- GitHub Actions CI baseline

更准确地说：

> **基础层已经开始成形，主线方向是对的；后续重点不再是“是否要这样设计”，而是继续把 runtime contract、文档同步和真实项目迁移体验收稳。**

---

## 目录结构（当前主线）

```text
Sources/Helios/
├── App/
│   ├── HeliosApp.swift
│   ├── HeliosAppDelegate.swift
│   ├── HeliosRouteRegistrar.swift
│   ├── HeliosRouteDescriptor.swift
│   └── HeliosFilterDescriptor.swift
├── Base/
│   ├── HeliosAppConfig.swift
│   ├── HeliosConfig.swift
│   └── HeliosConfigLoader.swift
├── Models/
│   └── HeliosModel.swift
├── Plugins/
│   ├── HeliosContext.swift
│   ├── HeliosFilter.swift
│   ├── HeliosTask.swift
│   ├── HeliosTaskDescriptor.swift
│   ├── HeliosTimer.swift
│   └── HeliosTimerDescriptor.swift
└── Views/
    ├── HeliosHandler.swift
    └── HeliosView.swift

Tests/
├── HeliosTests/
│   ├── Fixtures/
│   │   └── TestHeliosApp.swift
│   ├── SmokeTests.swift
│   ├── IntegrationTests.swift
│   ├── ContextAwareTests.swift
│   └── DescriptorTests.swift
└── README.md
```

---

## 快速理解：Helios 现在怎么工作

一个 Helios 应用大致按下面方式启动：

1. 业务项目实现一个 `HeliosAppDelegate`
2. 在 delegate 中：
   - 可以继续提供 legacy builder API
   - 也可以开始提供新的 descriptor/provider API
3. 使用 `HeliosApp.create(workspace:delegate:)`
4. 框架通过 `HeliosConfigLoader` 加载配置：
   - `base.json`
   - `<env>.json`
   - environment variables
5. 框架在 `setup()` 中分阶段完成装配：
   - HTTP server
   - MySQL / Redis / Queues
   - models / migrations
   - views / static files
   - filters
   - routes
   - timers / tasks
6. 调用 `run()` 启动应用

---

## 快速开始

### 1. 添加依赖

```swift
.package(url: "https://github.com/enums/Helios.git", branch: "main")
```

### 2. 实现一个最小 Delegate（legacy 路径）

```swift
import Vapor
import Helios

final class AppDelegate: HeliosAppDelegate {
    func routes(app: HeliosApp) -> [String: [HTTPMethod: HeliosHandlerBuilder]] {
        [
            "/ping": [
                .GET: PingHandler.builder
            ]
        ]
    }
}

struct PingHandler: HeliosHandler {
    init() {}

    func handle(req: Request) async throws -> AsyncResponseEncodable {
        Response(status: .ok, body: .init(string: "pong"))
    }
}
```

### 3. 准备配置文件

当前推荐配置组织方式：

```text
Config/
  base.json
  development.json
  production.json
```

环境选择通过：

```bash
HELIOS_ENV=development
```

覆盖关键项可通过环境变量，例如：

```bash
HELIOS_SERVER_HOST=0.0.0.0
HELIOS_SERVER_PORT=8080
HELIOS_MYSQL_HOST=127.0.0.1
HELIOS_MYSQL_USERNAME=root
HELIOS_MYSQL_PASSWORD=secret
HELIOS_MYSQL_DATABASE=helios
```

### 4. 启动应用

```swift
let helios = try HeliosApp.create(workspace: "/path/to/workspace/", delegate: AppDelegate())
try helios.run()
```

---

## 新旧扩展点 API：现在如何理解

Helios 当前采用的是**双轨过渡**：

### Legacy API（仍然支持）
- route dictionary
- handler / filter / task / timer builder

### New API（推荐主线）
- `HeliosRouteDescriptor`
- `HeliosFilterDescriptor`
- `HeliosTaskDescriptor`
- `HeliosTimerDescriptor`

当前框架行为是：

> **descriptor-first, fallback-to-legacy**

也就是说：
- 如果你提供了 descriptor，新接口优先
- 如果 descriptor 为空，就回退到旧 builder API

---

## 本地 lint

在仓库根目录运行：

```bash
./scripts/lint.sh
```

可选：直接使用 `swiftlint`（与 CI lint 行为对齐，默认在仓库根目录执行）：

```bash
swiftlint
```

这让迁移可以逐步进行，而不是一次性重写所有接入点。

---

## 测试

运行：

```bash
swift test
```

当前测试覆盖：
- smoke
- integration
- context-aware 构造
- descriptor/provider API

测试特点：
- **零外部依赖**
- fixture 可复用
- 后续 runtime contract / 迁移路径都可以继续在这套脚手架上补测试

更详细说明见：
- `Tests/README.md`

---

## CI

Helios 已经接入第一版 GitHub Actions CI。

当前 baseline 目标：
- lint
- build
- test

设计原则是：
- 先提供稳定红绿反馈
- 先不把 service containers / release workflow / 重型 matrix 一起拉进来

也就是说，当前 CI 更偏“基础健康检查”，不是最终形态。

---

## 当前已知限制 / 仍在演进的方向

虽然主线已经推进很多，但 Helios 还没有完全收口到“成熟框架”阶段。

当前仍需持续演进的重点包括：

1. **runtime contract 仍然偏薄**
   - 尤其是 task / timer 的幂等、失败策略、关停语义、可观测性
2. **README / docs 需要持续跟上主线代码**
3. **真实下游迁移体验还需要继续验证**
   - 尤其是 Blog 这种真实接入方
4. **CI baseline 还在继续收稳**
   - 目前主线已经接通，但版本 / runner 组合仍在打磨

所以当前更准确的判断是：

> **Helios 已经具备了“进入持续演进”的基础设施，但还在继续打磨长期运行与迁移体验。**

---

## 适用场景

Helios 当前更适合：
- 你自己主导的 Swift 服务端项目
- 中小型网站或 API 服务
- 希望长期跑在 Linux 上
- 希望框架精简，但不是纯散装 Vapor app

它目前还不适合期待以下特性的场景：
- 开箱即用的大型企业级平台能力
- 成熟的多数据库 / 多队列 / 多租户抽象
- 非常重的插件生态或复杂配置中心

---

## 现在如果你准备继续推进 Helios，建议先看哪里

最值得优先看的主线文件：
- `Sources/Helios/App/HeliosApp.swift`
- `Sources/Helios/Base/HeliosConfig.swift`
- `Sources/Helios/Base/HeliosConfigLoader.swift`
- `Sources/Helios/App/HeliosAppDelegate.swift`
- `Sources/Helios/App/HeliosRouteRegistrar.swift`
- `Tests/HeliosTests/Fixtures/TestHeliosApp.swift`
- `Tests/README.md`

如果你准备继续推进下一阶段，优先建议：
- runtime contract / observability
- 真实下游迁移验证
- README / docs 持续同步

---

## 当前总体判断

如果用一句话总结今天这个阶段的 Helios：

> **方向正确，基础层已经成形，主线已经能支撑继续往“轻量但可演进的 Linux 后端框架”推进。**
