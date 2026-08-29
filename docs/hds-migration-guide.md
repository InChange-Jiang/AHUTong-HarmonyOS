# 鸿蒙官方 UI 组件库（@kit.UIDesignKit）迁移指南

> 本文档记录 AHUTong-HarmonyOS 从自定义组件（AhuToolbar / 伪路由）迁移到官方 HDS 组件体系（HdsNavigation / HdsNavDestination / HdsTabs）的正确跑通逻辑与踩坑记录。
> 用于避免后续迁移 13 个页面时重复踩坑。

## 〇、官方资料入口（先看这里）

### UI 设计规范官网（Design Guide，交互/视觉规范）

总入口：**https://developer.huawei.com/consumer/cn/doc/design-guides**

常用设计指南子页面（从总入口搜索，或直达）：

| 指南 | 直达链接 | 用途 |
|---|---|---|
| 标题栏 | https://developer.huawei.com/consumer/cn/doc/design-guides/titlebar-0000001929628982 | 标题栏结构、按钮数量上限（3）、沉浸式规范 |
| 底部页签 | https://developer.huawei.com/consumer/cn/doc/design-guides/bottomtab-0000001956787789 | 平铺 48vp / 悬浮 56vp、图标 24vp、距底 28vp |
| 导航栏 / 其他组件 | 总入口内检索"导航""卡片""对话框"等 | 各组件的设计规范 |

> 用法：做任何 UI 改造前，先到 design-guides 找对应组件的设计规范页，确认尺寸/间距/状态规范，再动手。

### 官方组件 API 参考文档（UIDesignKit 组件级别）

| 参考 | 直达链接 |
|---|---|
| HdsNavigation 组件参考 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdsnavigation |
| HdsTabs 悬浮样式 | https://device.harmonyos.com/cn/docs/apiref/harmonyos-guides/ui-design-hds-tabs-bar-floating |
| UI Design Kit 介绍（华为开发者社区实战） | https://developer.huawei.com/consumer/cn/blog/topic/03212369425758084 |

> 注意：API 参考页为 JS 渲染，WebFetch 抓不到正文；需要精确 API 时直接读本机 SDK 类型定义：
> `C:\Program Files\Huawei\DevEco Studio\sdk\default\hms\ets\api\@hms.hds.hdsBaseComponent.d.ets`（HDS 组件全量定义）

## 〇·一、如何调用官方 UI 设计库（UIDesignKit 通用流程）

UI Design Kit（`@kit.UIDesignKit`）是华为官方组件库，把 HarmonyOS Design 设计语言封装成可直接使用的 HDS 组件（导航、页签、对话框、菜单、动作条等）。调用分三步：

### Step 1：确认 SDK 版本支持

在工程根目录 `build-profile.json5` 中查看 `compatibleSdkVersion`，需 ≥ 目标组件要求的版本：

```json5
// build-profile.json5
{
  "products": [{ "compatibleSdkVersion": "6.1.0(23)", "runtimeOS": "HarmonyOS" }]
}
```

- 组件最低版本看组件参考文档的 `@since`（如 HdsNavigation `@since 5.1.0(18)`）
- 悬浮式 HdsTabs 需要 `6.1.0(23)`（当前项目正好满足）

### Step 2：import 引入

```typescript
// 按需引入，不要整库导入
import { HdsTabs, HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { hdsMaterial } from '@kit.UIDesignKit';  // 材质（沉浸光感）
import { HdsTabsController } from '@kit.UIDesignKit';  // 页签控制器（如需要）
```

> `@kit.UIDesignKit` 是 SDK 自带的 kit，不需要额外 oh-package 依赖，DevEco Studio 直接可用。

### Step 3：在组件 build 中使用（声明式）

```typescript
@Component
export struct MyPage {
  build() {
    HdsNavDestination() {
      // 内容
    }
    .titleBar({ content: { title: {...}, menu: {...} } });
  }
}
```

### 通用排查顺序（组件用不起来时）

1. 先查 design-guides 设计规范页（确认设计层面是否允许这么做）
2. 再查组件参考文档的 `@since`（确认 SDK 版本）
3. 读本机 SDK 定义文件确认 API 签名（见上方 API 参考文档表格）
4. 参考华为开发者社区的接入实战（如 Jack 实战：悬浮导航 + 沉浸光感）

## 一、环境与版本约束

| 项目 | 值 | 说明 |
|---|---|---|
| compatibleSdkVersion | `6.1.0(23)` | 悬浮式 HdsTabs（`barFloatingStyle`）**最低要求此版本** |
| targetSdkVersion | `6.1.0(23)` | 同上 |
| HdsNavigation / HdsNavDestination | `@since 5.1.0(18)` | 6.1.0(23) 完全支持 |
| HdsTabs 悬浮样式 | `@since 6.1.0(23)` | `barFloatingStyle` 需要 23 |

## 二、正确引入方式（必须）

```typescript
// 官方 UI 组件库：导航容器 + 悬浮页签 + 二级页面
import { HdsTabs, HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
```

### 组件层级结构（官方推荐）

```
HdsNavigation(this.pathStack)   // 最外层：整页的壳、系统安全区、顶层材质
  └─ HdsTabs({...})             // 中间层：底部页签切换 + 悬浮底栏（主框架）
       ├─ TabContent() { HomePage() }      .tabBar(BottomTabBarStyle)
       ├─ TabContent() { WeeklySchedulePage() }.tabBar(...)
       ├─ TabContent() { ToolsPage() }     .tabBar(...)
       └─ TabContent() { SettingsPage() }  .tabBar(...)
  └─ navDestination((name, param) => { if (name === 'grade') GradePage() })  // 二级页面
```

## 三、正确跑通逻辑（核心代码模式）

### 1. AppRoot 导航容器（根容器）

```typescript
@Component
export struct AppRoot {
  // NavPathStack 是 ArkUI 全局类型，不需要 import！
  private readonly pathStack: NavPathStack = new NavPathStack();

  build() {
    Stack() {
      AppLaunchGate({ rejectAction: () => this.terminateApplication() }) {
        HdsNavigation(this.pathStack) {
          this.postLoginContent();   // 主框架：HdsTabs + 其余伪路由页面
        }
        .hideTitleBar(true)          // 根容器不需要标题栏（主框架用 tab）
        .navDestination((name: string, param: Object) => {
          if (name === 'grade') {
            GradePage();             // 路由映射：push 进来的页面
          }
        });
      }
    }
    .width('100%')
    .height('100%');
  }
}
```

### 2. 页面跳转（替代伪路由 activePage）

```typescript
// 错误：直接 new NavPathStack() 会报错
// import { NavPathStack } from '@kit.ArkUI';  // ❌ no exported member

// 正确：NavPathStack 全局类型直接用；ArkTS 不允许 untyped object literal
interface GradeRouteParam { }   // 先声明路由参数类型

onOpenWidget: (route: string) => {
  if (route === 'grade') {
    this.pathStack.pushPathByName('grade', {} as GradeRouteParam);
  }
}
```

### 3. 二级页面改造（GradePage Pilot 模板）

```typescript
import { HdsNavDestination } from '@kit.UIDesignKit';

@Component
export struct GradePage {
  @State searchActive: boolean = false;
  @State termSheetVisible: boolean = false;
  // ...业务状态

  build() {
    HdsNavDestination() {
      // 内容区（原 build 内容，去掉 AhuToolbar 和 onBack）
      Column({ space: 16 }) {
        if (this.searchActive) { this.searchBar(); }   // 搜索框在内容区顶部
        // ... 列表 / 加载 / 空态
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AhuColors.pageBackground);
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '成绩单',                      // 主标题
          subTitle: this.termLabel(this.selected()) // 副标题（ResourceStr）
        },
        menu: {
          maxCount: 3,                              // 最多 3 个按钮（官方规范上限）
          value: [
            { content: { icon: $r('sys.symbol.magnifyingglass'),
                         action: () => { this.searchActive = true; } } },
            { content: { icon: $r('sys.symbol.line_3_horizontal'),
                         action: () => { this.termSheetVisible = true; } } },
            { content: { icon: $r('sys.symbol.arrow_clockwise'),
                         action: () => { this.load(true); } } }
          ]
        }
      }
    })
    .bindSheet($$this.termSheetVisible, this.termSheet(), {
      title: { title: '选择学期' },       // SheetTitleOptions
      height: SheetSize.MEDIUM,           // ⚠️ 用 height，不是 size！
      showClose: true,
      dragBar: true
    })
    .onBackPressed((): boolean => {       // 返回拦截：先处理搜索态
      if (this.searchActive) {
        this.searchActive = false;
        this.query = '';
        return true;                      // true = 消费返回；false = 走系统 pop
      }
      return false;
    });
  }
}
```

## 四、踩坑记录（务必遵守）

### 坑 1：NavPathStack 不能 import
- **现象**：`Module '"@kit.ArkUI"' has no exported member 'NavPathStack'`
- **原因**：NavPathStack 是 ArkUI 全局类型（同 BarMode / BlurStyle / BarPosition），无需 import
- **解决**：删掉 import，直接用

### 坑 2：SheetOptions 没有 size 字段
- **现象**：`'size' does not exist in type 'SheetOptions'`
- **解决**：用 `height: SheetSize.MEDIUM`（SheetSize | Length）

### 坑 3：ArkTS 禁止 untyped object literal
- **现象**：`Object literal must correspond to some explicitly declared class or interface`
- **解决**：`pushPathByName('grade', {} as GradeRouteParam)`，接口先声明：
  `interface GradeRouteParam { }`

### 坑 4：两种 titleBar 结构不同（重点）
- **HdsNavigation.titleBar**（根容器）：一级结构
  ```typescript
  .titleBar({ title: '漫游周刊', subtitle: '...', style: {...} })
  ```
- **HdsNavDestination.titleBar**（二级页面）：content 嵌套结构
  ```typescript
  .titleBar({ content: { title: { mainTitle, subTitle }, menu: {...} }, style: {...} })
  ```
- 二级页面**必须用 content 结构**，否则菜单不生效

### 坑 5：菜单图标用 $r()，不要用 SymbolGlyphModifier
- 官方示例：`icon: $r('sys.symbol.magnifyingglass')`
- `new SymbolGlyphModifier(...)` 用在 `BottomTabBarStyle`（HdsTabs 页签）没问题，但菜单项建议用 `$r()`，运行时更稳
- 图标与文本间距由官方内置布局决定，无法精确控制为 2vp

### 坑 6：返回与系统返回的协调
- HdsNavDestination 自带返回按钮 + 原生转场动画
- 系统返回由 `Index.ets` 的 `onBackPress` → `BackPressDispatcher` 处理；**NavPathStack 栈非空时 Navigation 优先消费返回**
- 页面内用 `onBackPressed((): boolean => {...})` 拦截（如搜索态先退搜索）

## 五、Pilot 现状（成绩单 GradePage 已完成）

- [x] AppRoot 引入 HdsNavigation + NavPathStack，成绩单走 `pushPathByName('grade')`
- [x] GradePage 改为 HdsNavDestination + 官方 titleBar（主副标题 + 3 菜单：搜索/筛选/刷新）
- [x] 筛选用官方 bindSheet 半模态；返回用 onBackPressed 拦截搜索态
- [ ] **"成绩单按钮点不动"排查中**（已加 hilog 日志：`onOpenWidget route=` / `pushPathByName grade` / `navDestination name=` / `create GradePage`，待真机复现确认是"点击未触发"还是"路由未创建页面"）

## 六、后续 13 个页面迁移清单（按此模板）

| 页面 | 模块 | 标题栏按钮 |
|---|---|---|
| 考场查询 | feature_exam | 筛选 |
| 校历 | feature_calendar | 刷新 |
| 空闲教室 | feature_classroom | 筛选 |
| 浴室缴费 | feature_payment | 刷新 |
| 电控缴费 | feature_payment | 刷新 |
| 校园卡充值 | feature_payment | 刷新 |
| 失物招领 | feature_portal | 搜索/筛选/更多 |
| 校园电话本 | feature_tools | 搜索/筛选 |
| 天气 | feature_weather | 设置/定位/刷新 |
| 学习资料 | feature_repository | 搜索 |
| 偏好设置 | feature_settings | - |
| 开源协议 | feature_settings | - |
| 贡献名单 | feature_settings | - |

迁移步骤（每页固定 4 步）：
1. 组件结构 `Page({onBack})` → `HdsNavDestination() {...}`
2. 标题栏 `AhuToolbar` → `.titleBar({ content: { title, menu } })`（菜单图标用 `$r('sys.symbol.xxx')`）
3. AppRoot：postLoginContent 移除该页面分支，onOpenWidget 改 `pushPathByName`
4. navDestination 增加路由映射

## 七、搜索框"占满标题栏"待实现方案

官方 titleBar 无内置搜索态。候选方案：
- **titleBar 的 `stackBuilder`（CustomBuilder，6.0.0+）**：搜索态时叠一层覆盖标题栏的搜索框
- 或 `bindToScrollable` / 滚动模糊配合
- 当前 Pilot 先放内容区顶部，验证通过后再升级

## 八、悬浮式底部页签关键参数（已落地）

```typescript
HdsTabs({ barPosition: BarPosition.End, index: this.selectedIndex }) { ... }
.scrollable(false)
.barMode(BarMode.Fixed)
.barOverlap(true)                    // 内容延伸到栏后（悬浮前提）
.barFloatingStyle({                  // 悬浮式（6.1.0(23)）
  barWidth: { smallWidth: 328, mediumWidth: 328, largeWidth: 328 },
  barBottomMargin: 28                // 下沿距底 28vp
})
.animationDuration(220)
```
- 悬浮式默认高度 56vp、图标 24vp（官方默认，无需设置）
- tabBar 用 `new BottomTabBarStyle(normal: SymbolGlyphModifier, selected: SymbolGlyphModifier, 文本)`
