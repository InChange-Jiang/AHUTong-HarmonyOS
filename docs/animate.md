# AHUTong 鸿蒙动画设计规范总结

## 参考资料
- [《便单》APP 动效设计分享](http://bbs.itying.com/topic/66d28f8c6e3c6500bcd75a2a)
- [华为官方：合理使用动画](https://developer.huawei.com/consumer/cn/doc/best-practices-V14/bpta-fair-use-animation-V14)
- [华为官方：动画衔接](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation-smoothing)

---

## 一、核心设计原则

### 功能性原则
每个动画都必须有明确目的：引导注意力、提供反馈、增强空间认知。没有目的的动画就是干扰。

### 性能优先原则
流畅的 60fps 比华丽的特效更重要。低端设备上要优雅降级。

### 用户控制原则
尊重无障碍设置中的"减少动态效果"，不强制添加动效。

---

## 二、弹性动画（Spring Motion）参数规范

参考便单项目的调试结果，使用 `@ohos.curves` 模块提供的弹簧曲线：

| 参数配置 | 适用场景 | 效果描述 |
|----------|----------|----------|
| `curves.springMotion(0.5, 0.7)` | 卡片点击、Tab切换、开关、轻量交互 | 震动一次，反馈清晰不夸张 |
| `curves.springMotion(1.0, 0.5)` | 页面转场、弹出面板、强调动效 | 震动两次，更有张力 |

参数说明：
- `response`：弹簧复位速度，值越大振荡效应越明显
- `dampingFraction`：阻尼系数，值越小振荡次数越多

优势：
- 自动继承手势速度，跟手动画过渡自然
- 动画中断时衔接平滑，没有突兀的停顿

---

## 三、时间规范

| 场景 | 时长 (ms) | 说明 |
|------|-----------|------|
| 短动画（反馈） | 150 | 点击、缩放、弹出 |
| 中等动画（转场） | 250 | 页面切换、列表入场 |
| 长动画（复杂） | 350 | 大型面板展开收起 |

---

## 四、曲线规范

| 场景 | 曲线 |
|------|------|
| 常规属性变化 | `Curve.EaseInOut` |
| 惯性减速 | `Curve.Friction` |
| 弹性反馈 | `springMotion(0.5, 0.7)` / `springMotion(1.0, 0.5)` |

---

## 五、高斯模糊应用规范

### 推荐场景
1. **底部导航栏**：`Tabs` 设置 `barOverlap: true` + 半透明
2. **列表顶部标题栏**：`Stack` 布局叠加模糊层
3. **展开式卡片头部**：背景模糊增强层次感

### 实现方式

**首选：backdropBlur + opacity**
```typescript
Stack() {
  List() { /* ... */ }
    .width('100%')
    .height('100%')

  Column()
    .height(56)
    .backgroundColor($r('app.color.pageBackground'))
    .opacity(0.8)
    .backdropBlur(60)

  Row() { /* 标题栏内容 */ }
    .padding({ left: 18, right: 18 })
    .height(56)
    .width('100%')
}
.alignContent(Alignment.Top)
```

**注意事项**：
- 过度使用会导致性能瓶颈（帧率下降）
- 背景必须半透明才能显现模糊效果

---

## 六、API选择最佳实践

| 场景 | API选择 | 原因 |
|------|---------|------|
| 自动属性变化 | `.animation()` | 最简单，状态变化自动动画 |
| 多属性同时变化 | `animateTo()` | 合并动画减少重绘 |
| 组件出现/消失 | `transition()` | 系统自动管理，性能更好 |
| 路由页面切换 | `pageTransition()` | 独立作用域，不影响组件 |

### 具体规则

1. **对显隐切换统一用 transition，而非 animateTo**
   - `if/else` 控制组件显隐时，在组件上加 `transition()`
   - 避免手动写 `animateTo` 控制透明度位移，性能更好

2. **多个属性变化合并到同一个 animateTo**
   - 单独多次 animateTo 会导致多次布局计算，丢帧率升高
   - 合并后丢帧率从 ~20% 降到 ~4%

3. **优先使用图形变换属性**
   - 用 `scale`/`translate`/`rotate` 替代修改 `width`/`height`
   - 图形变换不会触发布局重排，性能更好

4. **跟手势衔接时继承速度**
   - 离手阶段动画初始速度继承手势速度
   - 避免速度不连续导致停顿感

---

## 七、性能优化要点

1. **只变化脏区域**：ArkUI 自动跟踪变化，只有变化的部分重绘
2. **避免嵌套过多动画**：深层嵌套会增加计算开销
3. **减少不必要的重绘**：合并动画到同一闭包
4. **尊重系统设置**：检查"减少动态效果"开关，适当简化

---

## 八、推荐动效场景（后期统一添加）

- [x] 底部 Tab 指示器弹性切换动画
- [x] 卡片点击反馈（0.96 → 1.0 缩放）
- [x] 列表条目入场渐入 + 上移
- [x] 弹出面板弹性进入
- [x] 开关切换动画（系统自带）
- [x] 导航栏高斯模糊

---

## 九、代码入口

动画 token 定义：
`core/designsystem/src/main/ets/theme/AhuAnimTokens.ets`
