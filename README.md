# Helios

Helios 是一个建立在 Vapor 之上的轻量后端框架骨架，目标是服务于：

- 中小型网站
- API 服务
- 长期运行在 Linux 上的 Swift 服务端应用

当前设计重点不是“大而全”，而是：

- **精简可用**
- **容易继续长大**
- **保留清晰的扩展点**

它目前更像一个偏框架化的应用骨架：已经有统一的 App 入口、Handler / Filter / Task / Timer / Model 抽象，也已经开始补测试脚手架和后续演进路线。

---

## 当前能力概览

基于当前仓库主线，Helios 主要提供这些抽象：

- `HeliosApp`
  - 框架主入口
  - 负责创建 `Application`、装配配置、注册路由 / 中间件 / 模型 / 队列 /定时任务等
- `HeliosAppDelegate`
  - 外部项目接入点
  - 通过 delegate 提供 routes / models / filters / timers / tasks
- `HeliosHandler`
  - HTTP handler 抽象
- `HeliosFilter`
  - 请求 / 响应过滤器抽象，基于 Vapor `AsyncMiddleware`
- `HeliosTask`
  - 后台任务抽象
- `HeliosTimer`
  - 定时任务抽象
- `HeliosModel`
  - Fluent model 抽象
- `HeliosAppConfig`
  - 当前配置读取入口（后续会重构为 typed config）

---

## 项目状态

Helios 目前正处在“骨架已经建立，正在往长期可演进框架推进”的阶段。

已经开始推进的工作包括：

- 补测试脚手架（smoke / integration baseline）
- 梳理配置系统重构计划
- 梳理启动编排收口计划
- 梳理扩展点依赖边界与运行时契约计划

如果用一句话概括当前状态：

> Helios 已经不是纯草稿，但也还没完全进入稳定框架阶段；现在最重要的是把配置、测试、启动编排和扩展边界这几层打磨硬。

---

## 目录结构

```text
Sources/Helios/
├── App/
│   ├── HeliosApp.swift
│   └── HeliosAppDelegate.swift
├── Base/
│   └── HeliosAppConfig.swift
├── Models/
│   └── HeliosModel.swift
├── Plugins/
│   ├── HeliosFilter.swift
│   ├── HeliosTask.swift
│   └── HeliosTimer.swift
└── Views/
    ├── HeliosHandler.swift
    └── HeliosView.swift

Tests/
├── HeliosTests/
│   ├── Fixtures/
│   │   └── TestHeliosApp.swift
│   ├── SmokeTests.swift
│   └── IntegrationTests.swift
└── README.md
```

---

## 快速理解：Helios 怎么工作

一个 Helios 应用大致按下面方式启动：

1. 业务项目实现一个 `HeliosAppDelegate`
2. 在 delegate 里提供：
   - routes
   - models
   - filters
   - timers
   - tasks
3. 使用 `HeliosApp.create(workspace:delegate:)`
4. 框架读取 `Config/config.json`
5. 框架在 `setup()` 里完成：
   - HTTP server 配置
   - MySQL 配置
   - Redis / Queues 配置
   - Route 注册
   - Migration 注册
   - Views / Middleware 配置
   - Timer / Task 注册
6. 调用 `run()` 启动应用

---

## 快速开始

### 1. 添加依赖

在你的 Swift Package 中依赖 Helios：

```swift
.package(url: "https://github.com/enums/Helios.git", branch: "main")
```

### 2. 实现一个最小 Delegate

```swift
import Vapor
import Helios

final class AppDelegate: HeliosAppDelegate {
    func routes(app: HeliosApp) -> [String : [HTTPMethod : HeliosHandlerBuilder]] {
        [
            "/ping": [
                .GET: PingHandler.builder,
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

当前版本默认从下面路径读取配置：

```text
<workspace>/Config/config.json
```

例如：

```json
{
  "hostname": "0.0.0.0",
  "port": "8080",
  "mysql_host": "127.0.0.1",
  "mysql_port": "3306",
  "mysql_username": "root",
  "mysql_password": "password",
  "mysql_database": "helios",
  "redis_host": "127.0.0.1",
  "redis_port": "6379"
}
```

> 注意：这套配置方案是当前实现，后续会升级为 typed config + 分层加载 + fail-fast。

### 4. 启动应用

```swift
let helios = try HeliosApp.create(workspace: "/path/to/workspace/", delegate: AppDelegate())
try helios.run()
```

---

## 测试

Helios 现在已经有第一版测试脚手架。

运行：

```bash
swift test
```

当前测试特点：

- 覆盖 smoke + integration baseline
- 零外部依赖
- 不需要 MySQL / Redis 即可跑
- 后续 issue 会继续在这套脚手架上补更多测试

更详细说明见：

- `Tests/README.md`

---

## 当前已知限制

Helios 目前还有一些明确待演进的点：

1. **配置系统偏弱**
   - 当前还是基于 `[String: String]`
   - 缺少 typed config / validate / env override

2. **启动编排过于集中**
   - `HeliosApp.setup()` 现在承担了过多职责

3. **扩展点依赖边界还不够清晰**
   - `Handler / Task / Timer` 目前更偏约定驱动

4. **运行时契约仍然偏薄**
   - 尤其是任务幂等、失败策略、关停行为、可观测性

5. **README / 文档 / 版本治理还在补齐中**

这些都已经被拆成了独立 issue，在逐步推进。

---

## 路线图（当前已拆成 issue）

当前主线计划包括：

- **#3** 配置系统重构：typed config + 分层加载 + fail-fast
- **#4** 启动编排收口：拆分 `HeliosApp setup` 阶段与子系统边界
- **#5** 扩展点演进：明确 `Handler / Task / Timer` 的依赖边界
- **#6** 后台运行时契约：补齐 `Task / Timer` 的幂等、重试与关停语义
- **#7** 质量基线建设：建立 smoke / integration test 与版本治理最小集
- **#8** 测试脚手架计划：建立 Helios 的 smoke / integration baseline

当前优先级已经调整为：

- **P0**: #8 测试脚手架（已完成第一版）
- **P1**: #3 配置系统重构、#4 启动编排收口
- **P2**: #5 扩展点演进、#6 后台运行时契约
- **P3**: #7 质量基线建设

---

## 适用场景

Helios 当前更适合：

- 你自己主导的 Swift 服务端项目
- 中小型网站或 API 服务
- 希望长期跑在 Linux 上
- 愿意接受“目前还在继续打磨框架边界”这个事实

它暂时**不适合**期待以下特性的场景：

- 开箱即用的大型企业级平台能力
- 已成熟稳定的多数据库 / 多队列 / 多租户框架抽象
- 非常重的插件生态或复杂配置中心

---

## 设计倾向

Helios 的当前设计倾向可以概括成：

- 基于 Vapor，但不只是直接写 Vapor app
- 用统一抽象把常见接入点收出来
- 优先保持代码短、路径清楚、后续可收口
- 先解决真实项目的可用性，再补框架治理与边界质量

---

## 开发说明

如果你准备继续推进 Helios，本仓库当前最值得优先看的文件是：

- `Sources/Helios/App/HeliosApp.swift`
- `Sources/Helios/App/HeliosAppDelegate.swift`
- `Sources/Helios/Base/HeliosAppConfig.swift`
- `Tests/HeliosTests/Fixtures/TestHeliosApp.swift`
- `Tests/README.md`

如果你要从当前路线图里挑一张卡先继续做，建议优先从：

- **#3 配置系统重构**

开始，因为这会直接影响后续所有能力的稳定演进。
