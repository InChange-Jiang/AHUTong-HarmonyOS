import { curves } from '@kit.ArkUI';

export class AhuAnimDurations {
  /** 短动画 / 反馈：150ms */
  static readonly short: number = 150;
  /** 中等动画 / 转场：250ms */
  static readonly medium: number = 250;
  /** 长动画 / 复杂展开收起：350ms */
  static readonly long: number = 350;
}

export class AhuAnimCurves {
  /** 常规属性变化 */
  static readonly default: Curve = Curve.EaseInOut;
  /** 惯性减速 */
  static readonly friction: Curve = Curve.Friction;

  /** 弹性反馈（震动一次）：卡片点击、Tab切换、轻量交互 */
  static get springTap(): ICurve {
    return curves.springMotion(0.5, 0.7);
  }

  /** 弹性强调（震动两次）：页面转场、弹出面板 */
  static get springEmphasis(): ICurve {
    return curves.springMotion(1.0, 0.5);
  }
}

export class AhuAnimations {
  /**
   * 卡片点击反馈动画：缩小 → 还原
   * 使用场景：卡片、按钮、列表项的点击反馈
   *
   * 使用方法：
   * ```typescript
   * Button('点击')
   *   .scale(this.scale)
   *   .animation(AhuAnimations.cardTap)
   * ```
   */
  static readonly cardTap: AnimateParam = {
    duration: AhuAnimDurations.short,
    curve: AhuAnimCurves.springTap
  };

  /**
   * 列表条目入场动画
   * 使用场景：列表数据加载后的渐入效果
   *
   * 使用方法：
   * ```typescript
   * ForEach(items, (item, index) => {
   *   ListItem()
   *     .transition(
   *       TransitionEffect.asymmetric(
   *         TransitionEffect.OPACITY
   *           .combine(TransitionEffect.translate({ y: 20 }))
   *           .animation({ duration: 250, curve: Curve.EaseInOut }),
   *         TransitionEffect.IDENTITY
   *       )
   *     )
   * })
   * ```
   */
  static readonly listItemEnter: AnimateParam = {
    duration: AhuAnimDurations.medium,
    curve: Curve.EaseInOut
  };

  /**
   * 页面转场动画
   * 使用场景：子页面进入/退出
   */
  static readonly pageTransition: AnimateParam = {
    duration: AhuAnimDurations.medium,
    curve: AhuAnimCurves.springEmphasis
  };

  /**
   * 弹窗/面板弹出动画
   * 使用场景：底部弹出面板、对话框
   */
  static readonly panelEnter: AnimateParam = {
    duration: AhuAnimDurations.medium,
    curve: AhuAnimCurves.springEmphasis
  };
}