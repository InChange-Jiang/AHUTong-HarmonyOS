# 小工具页面 UI 规范（v1）

> 配套文档：`docs/animate.md`（动画规范）
> 设计 token 来源：`core/designsystem/src/main/ets/theme/AhuTokens.ets`、`AhuAnimTokens.ets`

## 1. 适用范围

以下 **11 个小工具页面** 统一遵循本规范：

| # | 页面 | 文件 |
|---|------|------|
| 1 | 校园电话本 | feature/tools/.../PhoneBookPage.ets |
| 2 | 天气 | feature/weather/.../WeatherPage.ets |
| 3 | 失物招领 | feature/portal/.../LostFoundPage.ets |
| 4 | 学习资料 | feature/repository/.../RepositoryPage.ets |
| 5 | 浴室缴费 | feature/payment/.../BathroomRechargePage.ets |
| 6 | 电费充值 | feature/payment/.../ElectricityRechargePage.ets |
| 7 | 校园卡充值 | feature/payment/.../CardRechargePage.ets |
| 8 | 校历 | feature/calendar/.../SchoolCalendarPage.ets |
| 9 | 成绩单 | feature/grade/.../GradePage.ets |
| 10 | 考场查询 | feature/exam/.../ExamPage.ets |
| 11 | 空闲教室 | feature/classroom/.../FreeClassroomPage.ets |

> 成绩单、考场查询、空闲教室按用户指示一并纳入（此前曾误归为"非小工具页"）。
> 首页、工具首页、设置及其子页面不在此范围，另行处理。

## 2. 页面骨架

```
Stack (全屏)
└── Column
    ├── AhuToolbar（标题栏，固定顶部，不参与滚动）
    └── Scroll（仅内容区滚动）
        └── 内容 Column
            space: AhuDimens.sectionSpacing
            padding.bottom: AhuDimens.bottomNavClearance
```

- **可滚动的只有内容区**，标题栏固定顶部，不随内容滚动。
- Scroll 设 `layoutWeight(1)` 占满剩余空间、`scrollBar(BarState.Off)`。
- **Scroll 必须加 `.align(Alignment.Top)`**：ArkUI 的 `Scroll` 默认 `align` 为 `Alignment.Center`，内容不足一屏时会在视口中央显示，必须显式设为 `Alignment.Top` 才能让内容始终紧贴标题栏顶部。
- **根容器必须 `.backgroundColor(AhuColors.pageBackground)`**（灰色打底），与页面背景一致（见 §3.4）。
- 弹窗（确认弹窗、筛选弹窗）作为 `Stack` 的直接子节点叠加，与标题栏/内容区同级。

## 3. 标题栏（AhuToolbar v2）

### 3.1 通用规则

- **保留返回按钮**（按开发者文档要求，非一级界面标题栏左侧需提供返回图标）。
  - 位置：标题栏最左侧。
  - 样式：40 × 40 圆形、`AhuColors.card` 背景，图标 `SymbolGlyph($r('sys.symbol.chevron_left'))`，图标色 `AhuColors.onSurface`。
  - 行为：点击调用 `onBack` 返回；系统边缘手势 / 系统返回键同样有效。
- 页面内 `BackPressDispatcher` 保留，用于"弹窗 > 搜索态 > 退出"的返回优先级。
- 左侧：标题文字。`fontSize: AhuTypography.pageTitle`，加粗，`AhuColors.onSurface`，单行省略。
- 右侧：操作区，图标按钮 **最多 3 个**（含更多入口），从重要到次要从左往右排。

### 3.2 图标按钮样式基准

- 尺寸：40 × 40 圆形
- 背景：`AhuColors.card`
- 图标色：`AhuColors.onSurface`
- 图标：统一使用 `SymbolGlyph`（`sys.symbol.*`）
- 按钮间距：`Row(space: 8)`
- 图标字号：**20**（返回键 22 除外）

| 功能 | 图标 |
|------|------|
| 返回 | `sys.symbol.chevron_left` |
| 搜索 | `sys.symbol.magnifyingglass` |
| 筛选 | `sys.symbol.line_3_horizontal` |
| 刷新 | `sys.symbol.arrow_clockwise` |

- 无操作按钮时右侧留空，标题保持居左。

### 3.3 标题栏尺寸（AhuToolbar 实际值）

| 项 | token / 值 |
|----|-----------|
| 顶部内边距 | `AhuDimens.titleTop` = 32 |
| 标题栏与内容区间距 | 16（基准取考场查询）；成绩单因主副标题用 12 |
| 左右内边距 | `AhuDimens.contentHorizontal` = 16 |
| 标题字号 | `AhuTypography.pageTitle` = 28，加粗 |
| 副标题字号 | `AhuTypography.label` = 14，`onSurfaceSecondary` |
| 返回键 | 40 × 40 圆形，`card` 背景，图标 22 |
| 操作图标按钮 | 40 × 40 圆形，`card` 背景，图标 20 |
| 图标按钮间距 | 8 |
| 搜索态搜索框 | 高 40、圆角 20、`card` 背景 |
| 搜索态"取消" | `primaryAction`，字号 16 |

> 标题栏高度由 `titleTop(32) + 按钮高度(40)` 决定，全部页面经 `AhuToolbar` 统一，不自行加高或改间距。

### 3.4 内容区与卡片基准

- **页面背景**：根容器 `.backgroundColor(AhuColors.pageBackground)`（灰色打底）。
- 内容区：`Scroll` 内 `Column(space: AhuDimens.sectionSpacing = 24)`，`padding.bottom: AhuDimens.bottomNavClearance = 96`。
- **内容一律卡片化**，统一使用 `AhuInsetCard`（圆角卡片带左右外边距）：

| 项 | token / 值 |
|----|-----------|
| 卡片组件 | `AhuInsetCard`（core/designsystem/.../AhuCard.ets） |
| 圆角 | `AhuDimens.cardCorner` = 32 |
| 背景 | `AhuColors.card`（白色） |
| 内边距 | 左右 `cardPaddingHorizontal` = 24，上下 `cardPaddingVertical` = 16 |
| 外边距 | 左右 `contentHorizontal` = 16 |

- 卡片内容文字层级：标题 `body(16)` 加粗；次要信息 `label(14)` + `onSurfaceSecondary`。
- 列表项、数据条目等次要分组可用 `AhuCard`（无外边距，需自行控制）或更小的圆角（`cardCornerMedium` = 16）。

### 3.5 已知偏差（截至 2026-08-28，待统一）

| 页面 | 偏差 |
|------|------|
| 校园电话本 / 浴室缴费 / 电控缴费 / 校园卡充值 / 失物招领 / 学习资料 | 根容器缺少 `.backgroundColor(AhuColors.pageBackground)`，页面为白色底，与标准灰色打底不一致；标题栏背景因此也呈白色，圆形按钮"白色圆圈"轮廓丢失 |
| 校园电话本（已改本轮） | 按钮映射已对齐：搜索 logo + 分类下拉；但背景待补 |
| 空闲教室 | 仍为旧式 `Row` 标题栏，未迁移 `AhuToolbar`（用户暂缓处理） |

> 标准基准以成绩单（GradePage）、考场查询（ExamPage）为参照。

### 3.6 组件 API 设计（改造目标）

```
AhuToolbar({
  title,
  searchable = false,     // 是否提供搜索入口
  filterable = false,     // 是否提供筛选入口
  refreshable = false,    // 是否提供刷新入口
  refreshing = false,     // 刷新中状态（图标旋转/禁用）
  searchPlaceholder = '搜索',
  onSearchInput,          // 搜索输入回调（实时过滤）
  onSearchExit,          // 退出搜索态回调
  onFilterClick,          // 筛选入口回调（页面自己弹面板）
  onRefresh,              // 刷新回调
  onBack,                 // 返回回调（必选，渲染左侧返回图标）
}) {
  // trailing closure 自定义操作插槽（普通态额外按钮，如"发布"）
}
```

- 搜索态：点击搜索图标 → 标题栏整行切换为搜索形态（见 §4）。
- 搜索/筛选/刷新入口图标由组件内部渲染；返回图标由 `onBack` 提供（必选）。
- 注意：沿用 trailing closure 传递 `@BuilderParam`，避免 `@Builder` 方法引用传字段导致的上下文丢失问题（参见此前 AppLaunchGate 修复经验）。

## 4. 搜索交互

1. 点击标题栏右侧搜索图标 → **弹出动画** → 标题栏整行切换为搜索形态：
   - 左侧：胶囊搜索框，占满标题栏剩余宽度，含放大镜图标 + placeholder；
   - 右侧：文字"取消"（`AhuColors.primaryAction`）。
2. 输入即过滤（`onChange` 实时过滤内容区列表）。
3. 点击"取消"或系统返回 → 动画收回，恢复标题形态，并清空搜索词。
4. 动画：以 `translate` + `opacity` + 宽度过渡实现展开/收起，时长为 `AhuAnimDurations.short`（150ms），曲线遵循 `AhuAnimTokens`（默认 `Curve.EaseInOut`）。
5. 搜索态下再按返回键应优先退出搜索态而非退出页面（由 BackPressDispatcher 处理）。

## 5. 筛选交互

1. 点击标题栏右侧筛选图标 → 弹出**独立筛选面板**（下拉面板，贴近华为官方 `Filter` 多条件筛选模式）。
2. 面板内容：多条件分组（如 状态 / 校区 / 类型），每组用 chip 单选或复选。
3. 面板底部操作：`重置` / `确定`。
4. 关闭方式：点击遮罩或"取消"。
5. 筛选生效时，筛选图标高亮为 `AhuColors.primaryAction`，提示当前有筛选条件。
6. 弹出动画：`AhuAnimations.panelEnter`（springEmphasis，250ms）。

## 6. 刷新交互

1. 点击标题栏右侧刷新图标 → 触发重新拉取数据。
2. 加载中：图标禁用或旋转；加载完成恢复。

## 7. 动画规范

引用 `docs/animate.md`，强制约束：

- 一律使用 `AhuAnimTokens` 中定义的时长与曲线，禁止散值。
- 优先 `transition()` / 显式 `animation()`；避免 `width/height` 布局动画（搜索框展开场景用 `max-width + opacity + translate` 组合）。

## 8. 各页面按钮映射

| 页面 | 搜索 | 筛选 | 刷新 | 其他操作 |
|------|:---:|:---:|:---:|----------|
| 校园电话本 | ✓ | ✓ | — | — |
| 天气 | ✓ | — | ✓ | — |
| 失物招领 | ✓ | ✓ | ✓ | 发布（文字胶囊按钮） |
| 学习资料 | — | — | ✓ | 管理 / 已下载 |
| 浴室缴费 | — | — | — | — |
| 电费充值 | — | — | — | — |
| 校园卡充值 | — | — | — | — |
| 校历 | — | — | ✓ | 保存 |
| 成绩单 | ✓ | ✓ | ✓ | 学期切换 = 筛选下拉 |
| 考场查询 | ✓ | — | ✓ | — |
| 空闲教室 | — | ✓ | — | 查询按钮（内容区） |

## 9. 改造清单

1. `AhuToolbar` v2：保留返回按钮（`SymbolGlyph` 返回图标）；新增搜索/筛选/刷新入口与搜索形态切换；保留 trailing closure 操作插槽。
2. 各页面按 §8 映射接入（共 11 个）：
   - 移除内容区原有的搜索框 / 筛选条，迁入标题栏（电话本、天气、失物招领、成绩单、考场查询的搜索框；失物招领、空闲教室的筛选区）；
   - 无搜索/筛选的页面（浴室/电费/校园卡充值）仅保留标题栏；
   - 每个页面保留并检查 `BackPressDispatcher` 返回优先级。
3. 筛选面板做成通用组件（如 `AhuFilterSheet`），供失物招领、空闲教室等页面复用。
