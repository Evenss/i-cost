# iCost 技术实现方案

## 1. 技术目标

根据 [design.md](./design.md)，第一版要实现一个极简 macOS 状态栏工具：

- 状态栏常驻显示今日美元花费
- 点击弹窗显示 Today、Daily Trend、Agents
- 管理界面只显示 Sources 和 Stats
- 支持 Claude Code 和 Codex
- 使用内置模型价格表
- 固定汇率 `1 USD = 7 CNY`
- 本地 SQLite 存储和聚合

技术实现要服务于产品原则：后台可以完整，前台必须克制。

## 2. 推荐技术栈

### 2.1 App

使用原生 macOS 技术：

- Swift
- SwiftUI
- AppKit
- NSStatusItem
- NSPopover
- SQLite

原因：

- 状态栏 App 需要 `NSStatusItem`，AppKit 是最直接的方案
- SwiftUI 适合写弹窗和管理界面
- SQLite 适合本地、轻量、可长期维护的数据聚合
- 不需要 Electron，避免体积和资源占用过重

### 2.2 App 形态

推荐结构：

```text
iCost.app
├── Status Bar Item
├── Popover
├── Management Window
├── Background Scanner
├── Local SQLite Store
└── Built-in Price Catalog
```

App 启动后默认不显示 Dock 图标，主要驻留在状态栏。

## 3. 架构分层

推荐分为五层：

```text
UI Layer
  ↓
View Model / App State
  ↓
Aggregation Service
  ↓
Source Adapters
  ↓
SQLite Store
```

### 3.1 UI Layer

负责展示：

- 状态栏金额
- 点击弹窗
- 管理窗口

UI 不直接读取日志，不直接计算价格。

### 3.2 View Model / App State

负责给 UI 提供已经聚合好的数据：

- 今日 USD / CNY
- 最近 N 天趋势
- 按 agent 花费
- source 状态
- 本周、本月统计

这一层的数据结构应当接近 UI 需求，避免 UI 理解底层 token、模型、价格表细节。

### 3.3 Aggregation Service

负责从底层 usage event 聚合成 UI 需要的数据：

- daily totals
- daily trend
- agent totals
- source health

这一层可以定时刷新，也可以由用户点击 Refresh 触发。

### 3.4 Source Adapters

每个 agent 一个 adapter：

- `ClaudeCodeAdapter`
- `CodexAdapter`
- 后续可增加 `CursorAdapter`

Adapter 职责：

- 发现默认日志路径
- 判断 source 是否可读取
- 增量扫描日志
- 解析为统一的 `UsageEvent`
- 维护扫描 cursor

Adapter 不负责 UI，不负责价格展示。

### 3.5 SQLite Store

负责持久化：

- source 状态
- usage event
- daily rollup
- 扫描 cursor
- 未识别模型

不保存 prompt 内容。

## 4. 数据流

完整数据流：

```text
Agent local logs
  ↓
Source Adapter
  ↓
Normalized UsageEvent
  ↓
Built-in Price Catalog
  ↓
CostedUsageEvent
  ↓
SQLite
  ↓
Daily / Agent Aggregation
  ↓
Status Bar / Popover / Management UI
```

关键点：

- 解析时保留模型和 token 字段
- 计算后只把聚合金额展示给用户
- 模型维度、token 类型维度不进入 UI
- 项目和会话信息不进入 UI，也不作为聚合维度

## 5. 核心数据模型

### 5.1 Source

```swift
enum AgentSource: String {
    case claudeCode
    case codex
}

struct SourceState {
    let source: AgentSource
    let displayName: String
    let isEnabled: Bool
    let status: SourceStatus
    let path: String?
    let lastSyncedAt: Date?
}
```

### 5.2 UsageEvent

统一后的底层事件：

```swift
struct UsageEvent {
    let id: String
    let source: AgentSource
    let occurredAt: Date
    let modelRawName: String
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let sourceFile: String
    let sourceOffset: Int64?
}
```

说明：

- `modelRawName` 只用于后台匹配价格
- token 字段只用于后台计算
- `id` 应当稳定，用于去重
- 不保存 prompt、response 或工具调用内容

### 5.3 CostedUsageEvent

计价后的事件：

```swift
struct CostedUsageEvent {
    let usageEventID: String
    let source: AgentSource
    let occurredAt: Date
    let costUSD: Decimal
    let isPriced: Bool
    let pricingModelKey: String?
}
```

说明：

- `pricingModelKey` 只用于调试和后续维护
- UI 不展示模型维度

### 5.4 DailyRollup

UI 主要读取这个聚合结果：

```swift
struct DailyRollup {
    let date: Date
    let totalUSD: Decimal
    let totalCNY: Decimal
    let agentTotals: [AgentSource: Decimal]
    let unpricedEventCount: Int
}
```

## 6. SQLite 表设计

### 6.1 sources

```sql
CREATE TABLE sources (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  enabled INTEGER NOT NULL,
  path TEXT,
  status TEXT NOT NULL,
  last_synced_at TEXT,
  updated_at TEXT NOT NULL
);
```

### 6.2 scan_cursors

```sql
CREATE TABLE scan_cursors (
  source_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  file_modified_at TEXT,
  last_offset INTEGER,
  last_event_key TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (source_id, file_path)
);
```

### 6.3 usage_events

```sql
CREATE TABLE usage_events (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  model_raw_name TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  cached_input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  source_file TEXT NOT NULL,
  source_offset INTEGER,
  created_at TEXT NOT NULL
);
```

### 6.4 costed_usage_events

```sql
CREATE TABLE costed_usage_events (
  usage_event_id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  cost_usd TEXT NOT NULL,
  priced INTEGER NOT NULL,
  pricing_model_key TEXT,
  created_at TEXT NOT NULL
);
```

`cost_usd` 使用 TEXT 保存 Decimal，避免浮点误差。

### 6.5 daily_rollups

```sql
CREATE TABLE daily_rollups (
  day TEXT NOT NULL,
  source_id TEXT NOT NULL,
  cost_usd TEXT NOT NULL,
  event_count INTEGER NOT NULL,
  unpriced_event_count INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (day, source_id)
);
```

### 6.6 unknown_models

```sql
CREATE TABLE unknown_models (
  model_raw_name TEXT NOT NULL,
  source_id TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  event_count INTEGER NOT NULL,
  PRIMARY KEY (model_raw_name, source_id)
);
```

未知模型只用于维护内置映射，不在主 UI 中展开。

## 7. 内置价格表

价格表写在代码里，随 App 发版维护。

### 7.1 数据结构

```swift
struct ModelPrice {
    let key: String
    let aliases: [String]
    let inputPerMillionUSD: Decimal
    let cachedInputPerMillionUSD: Decimal?
    let outputPerMillionUSD: Decimal
}
```

### 7.2 匹配规则

模型名匹配流程：

```text
raw model name
→ lowercase
→ trim spaces
→ normalize separators
→ exact alias match
→ fallback contains match, only for明确安全的别名
```

优先使用精确匹配。模糊匹配必须保守，避免把不同价格的模型错算成同一类。

### 7.3 计算公式

```text
cost_usd =
  input_tokens / 1_000_000 * input_price
+ cached_input_tokens / 1_000_000 * cached_input_price
+ output_tokens / 1_000_000 * output_price
```

如果某个模型没有单独的 cached input 价格：

```text
cached_input_price = input_price
```

人民币估算：

```text
cost_cny = cost_usd * 7
```

## 8. Source Adapter 设计

### 8.1 Adapter 协议

```swift
protocol UsageSourceAdapter {
    var source: AgentSource { get }
    var displayName: String { get }

    func discover() async -> SourceDiscoveryResult
    func scan(since cursor: ScanCursor?) async throws -> [UsageEvent]
}
```

### 8.2 Claude Code Adapter

职责：

- 找到 Claude Code 本地 usage/session 日志
- 增量读取新增记录
- 从日志中提取时间、模型名、token usage
- 转成 `UsageEvent`

实现时需要注意：

- 日志格式可能随版本变化
- 解析器要容忍字段缺失
- 只读取 usage 相关字段
- 不保存 prompt / response 文本

### 8.3 Codex Adapter

职责与 Claude Code 类似：

- 找到 Codex 本地 session/transcript 日志
- 增量扫描
- 提取模型名与 token usage
- 转成统一事件

Codex 的日志结构需要在实现阶段用真实本地样本校验。

## 9. 刷新策略

### 9.1 自动刷新

MVP 推荐：

- App 启动后立即扫描一次
- 后台每 5 分钟扫描一次
- 用户点击 Refresh 时立即扫描一次

扫描应当是增量的：

- 优先根据文件路径和 offset 继续读
- 文件变小或修改时间异常时重新扫描该文件并依靠事件 ID 去重

### 9.2 UI 更新

扫描完成后：

1. 写入新 usage events
2. 计算 costed events
3. 更新 daily rollups
4. 发布 AppState
5. 状态栏金额刷新

状态栏不应频繁闪烁。只有金额变化时更新标题。

## 10. UI 实现

### 10.1 状态栏

使用 `NSStatusBar.system.statusItem`。

显示规则：

```text
$0.00
$3.42
$128
```

金额格式：

- 小于 `$100`：保留两位小数
- 大于等于 `$100`：显示整数

### 10.2 Popover

使用 `NSPopover + SwiftUI View`。

内容固定为三块：

- Today
- Daily Trend
- Agents

底部操作：

- Refresh
- Manage

Popover 不显示：

- 模型
- token 类型
- 项目
- 会话
- 价格表
- 汇率设置

### 10.3 Management Window

使用普通 SwiftUI window。

只包含两个 tab：

- Sources
- Stats

Sources 页面字段：

- agent 名称
- enabled
- ready / missing / disabled
- last synced

Stats 页面字段：

- Today
- This Week
- This Month
- Daily Trend
- Agent totals

## 11. 隐私设计

默认本地处理，不上传任何数据。

存储原则：

- 保存 token 数量
- 保存模型名
- 保存 agent 来源
- 保存时间
- 保存本地文件路径和 offset
- 不保存 prompt
- 不保存 completion
- 不保存工具调用参数

日志解析时即使读到 prompt 内容，也应丢弃。

## 12. 错误处理

错误处理保持低打扰。

### 12.1 Source 不可读

Sources 页面显示：

```text
Claude Code    Enabled    Missing
```

不弹窗。

### 12.2 未知模型

不计入金额，记录到 `unknown_models`。

主界面最多显示一条轻提示：

```text
Some usage could not be priced
```

### 12.3 数据库错误

如果 SQLite 初始化失败：

- 状态栏显示 `--`
- Popover 显示简短错误
- 允许用户重试

不崩溃退出。

## 13. MVP 开发顺序

推荐按这个顺序实现：

1. 创建 macOS menu bar app 骨架
2. 实现 AppState 和 UI 静态数据
3. 实现 SQLite schema 和 repository
4. 实现内置 PriceCatalog
5. 实现 cost calculation
6. 实现 Codex adapter
7. 实现 Claude Code adapter
8. 实现 daily rollup
9. 接入真实 UI 数据
10. 做本地样本测试和边界测试

这个顺序可以先让界面跑起来，再逐步替换真实数据。

## 14. 测试策略

### 14.1 单元测试

重点测试：

- model alias 匹配
- cost calculation
- USD to CNY
- event id 去重
- daily rollup
- unknown model 记录

### 14.2 Adapter Fixture 测试

为每个 source 准备脱敏 fixture：

```text
Tests/Fixtures/claude-code/*.jsonl
Tests/Fixtures/codex/*.jsonl
```

测试目标：

- 能解析 token usage
- 字段缺失时不崩溃
- prompt 内容不会入库
- 重复扫描不会重复计费

### 14.3 UI Smoke Test

手动验证：

- 状态栏金额正确
- 点击弹窗正常
- Refresh 正常
- Manage 正常
- Sources 状态正确
- Stats 趋势正确

## 15. 文件结构建议

```text
iCost/
├── App/
│   ├── iCostApp.swift
│   ├── AppDelegate.swift
│   └── StatusItemController.swift
├── UI/
│   ├── Popover/
│   ├── Management/
│   └── Components/
├── Core/
│   ├── Models/
│   ├── PriceCatalog/
│   ├── Aggregation/
│   └── Formatting/
├── Sources/
│   ├── UsageSourceAdapter.swift
│   ├── ClaudeCodeAdapter.swift
│   └── CodexAdapter.swift
├── Storage/
│   ├── Database.swift
│   ├── Migrations/
│   └── Repositories/
└── Tests/
    ├── PriceCatalogTests/
    ├── AggregationTests/
    └── AdapterTests/
```

## 16. 需要提前确认的问题

实现前建议确认三件事：

1. 第一版是否只支持 Claude Code 和 Codex
2. 状态栏是否固定只显示 USD
3. 未知模型提示是否出现在弹窗，还是只出现在管理界面

除此之外，技术方案可以直接按 MVP 开始做。
