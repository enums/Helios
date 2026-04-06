# Helios Test Scaffold

## 目录结构

```
Tests/
└── HeliosTests/
    ├── Fixtures/
    │   └── TestHeliosApp.swift    # 测试 harness：TestDelegate, test handlers/filters, makeTestApp()
    ├── SmokeTests.swift           # 冒烟测试：框架类型实例化、单路由注册与响应
    └── IntegrationTests.swift     # 集成测试：filter 链、多路由组合、config 负面路径
```

## 设计原则

1. **零外部依赖**：所有测试都不需要 MySQL、Redis 或任何外部服务。通过 `makeTestApp()` 创建轻量 Vapor `Application(.testing)`，只注册路由和 filter。
2. **Fixture 复用**：`TestDelegate`、`EchoHandler`、`TestHeaderFilter` 等放在 `Fixtures/` 目录下，所有测试文件共享。
3. **逐步扩展**：后续 issue 在此脚手架上补测试，不另起炉灶。

## 运行

```bash
cd Helios
swift test
```

## 如何在此脚手架上补测试

1. 如果需要新的 test handler/filter，加到 `Fixtures/TestHeliosApp.swift`
2. 如果是新模块的测试，创建新的 `*Tests.swift` 文件
3. 所有测试应保持 **零外部依赖**，除非是明确标记为需要基础设施的集成测试
4. 使用 `makeTestApp(delegate:)` 创建测试用 app，配置 delegate 的 `routeTable` / `filterList` 后调用

## 测试层次

| 层次 | 文件 | 覆盖内容 |
|------|------|---------|
| Smoke | `SmokeTests.swift` | 协议实例化、单路由注册、JSON 响应、404 |
| Integration | `IntegrationTests.swift` | Filter 链、请求拦截、多路由组合、Config 负面路径 |
