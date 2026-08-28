import { AhuColors, AhuDimens, AhuInsetCard, AhuPageHeader, AhuTypography } from 'core_designsystem';
import { AhuCache } from 'core_datastore';
import { common } from '@kit.AbilityKit';
import { BackPressDispatcher } from 'core_common';

@Component
export struct SettingsPage {
  @State message: string = '';
  @State showClear: boolean = false;
  @State clearing: boolean = false;
  @State debugTapCount: number = 0;
  private lastDebugTap: number = 0;
  active: boolean = false;
  appVersion: string = '';
  onLogout: () => Promise<void> = async () => {};
  onClearAllData: () => Promise<void> = async () => {};
  debugEnabled: boolean = false;
  onOpenPreferences: () => void = () => {};
  onOpenLicense: () => void = () => {};
  onOpenContributors: () => void = () => {};
  onOpenDebug: () => void = () => {};

  aboutToAppear(): void { BackPressDispatcher.register('settings_page', () => this.handleBackPress()); }
  aboutToDisappear(): void { BackPressDispatcher.unregister('settings_page'); }

  private handleBackPress(): boolean {
    if (!this.active) return false;
    if (this.showClear) { this.showClear = false; return true; }
    return false;
  }

  private debugTap(): void {
    if (!this.debugEnabled) return;
    const now = Date.now();
    this.debugTapCount = now - this.lastDebugTap <= 1_000 ? this.debugTapCount + 1 : 1;
    this.lastDebugTap = now;
    if (this.debugTapCount >= 8) { this.debugTapCount = 0; this.onOpenDebug(); }
  }

  private async feedback(): Promise<void> {
    try { const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({ action: 'ohos.want.action.viewData',
        uri: 'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=1006203134&card_type=group&source=qrcode' });
    } catch (_) { this.message = '请安装 QQ 或 TIM'; }
  }

  private async logout(): Promise<void> {
    if (this.clearing) return; this.clearing = true;
    try { await this.onLogout(); } finally { this.clearing = false; }
  }

  private async clearAll(): Promise<void> {
    if (this.clearing) return; this.clearing = true;
    try { await this.onClearAllData(); this.showClear = false; } finally { this.clearing = false; }
  }

  private termLabel(): string {
    const schoolYear = AhuCache.getSchoolYear() ?? '--';
    const storedTerm = AhuCache.getSchoolTerm() ?? '';
    const parts = storedTerm.split('-');
    const term = parts.length >= 3 ? parts[parts.length - 1] : storedTerm;
    return `${schoolYear} 学年 · 第 ${term.length > 0 ? term : '--'} 学期`;
  }

  @Builder private item(title: string, subtitle: string, onTap: () => void) {
    AhuInsetCard() {
      Row() {
        Column({ space: 3 }) { Text(title).fontSize(AhuTypography.body).fontWeight(FontWeight.Medium);
          Text(subtitle).fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary); }
        .alignItems(HorizontalAlign.Start).layoutWeight(1);
        Text('›').fontSize(26).fontColor(AhuColors.onSurfaceSecondary);
      }.width('100%').onClick(() => { onTap(); });
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: AhuDimens.sectionSpacing }) {
          AhuPageHeader({ title: '设置' });
        AhuInsetCard({ containerColor: AhuColors.accentSurface }) {
          Row({ space: 16 }) {
            Image($r('app.media.startIcon')).width(64).height(64).borderRadius(18);
            Column({ space: 5 }) { Text('安大通').fontSize(24).fontWeight(FontWeight.Bold);
              Text(`${this.appVersion} · HarmonyOS`).fontSize(AhuTypography.body).fontColor(AhuColors.onSurfaceSecondary); }
            .alignItems(HorizontalAlign.Start);
          }.width('100%');
        }
        Text('账户信息').fontSize(AhuTypography.sectionTitle).fontWeight(FontWeight.Bold).padding({ left: 20 });
        AhuInsetCard() {
          Column({ space: 5 }) {
            Text(AhuCache.getCurrentUser()?.name ?? '未登录').fontSize(AhuTypography.sectionTitle).fontWeight(FontWeight.Bold);
            Text(this.termLabel())
              .fontColor(AhuColors.onSurfaceSecondary);
          }.width('100%').alignItems(HorizontalAlign.Start).onClick(() => this.debugTap());
        }
        AhuInsetCard() {
          Row() { Text('退出登录').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium).layoutWeight(1);
            Text('›').fontSize(26); }.width('100%').onClick(() => this.logout());
        }
        this.item('偏好设置', '提醒与主题颜色', this.onOpenPreferences);
        Text('关于').fontSize(AhuTypography.sectionTitle).fontWeight(FontWeight.Bold).padding({ left: 20 });
        this.item('开源协议', '查看第三方软件许可', this.onOpenLicense);
        this.item('贡献名单', '感谢每一位项目贡献者', this.onOpenContributors);
        AhuInsetCard() {
          Row() { Column({ space: 3 }) { Text('意见反馈').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium);
            Text('加入安大通反馈群').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary); }
            .alignItems(HorizontalAlign.Start).layoutWeight(1); Text('›').fontSize(26); }
          .width('100%').onClick(() => this.feedback());
        }
        if (this.message.length > 0) Text(this.message).fontColor(AhuColors.error).padding({ left: 20 });
        AhuInsetCard() {
          Row() { Column({ space: 3 }) { Text('清除数据').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium);
            Text('清除登录状态、课表和缓存').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary); }
            .alignItems(HorizontalAlign.Start).layoutWeight(1); Text('›').fontSize(26); }
          .width('100%').onClick(() => { this.showClear = true; });
        }
      }
      .width('100%')
      .padding({ bottom: AhuDimens.bottomNavClearance });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
    if (this.showClear) {
      Column({ space: 16 }) {
        Text('清除所有数据？').fontSize(AhuTypography.sectionTitle).fontWeight(FontWeight.Bold);
        Text('您的登录状态、课表等信息将会被永久清除').fontColor(AhuColors.onSurfaceSecondary);
        Row({ space: 10 }) {
          Button('取消', { type: ButtonType.Capsule }).enabled(!this.clearing).onClick(() => { this.showClear = false; });
          Button(this.clearing ? '清除中' : '清除', { type: ButtonType.Capsule }).enabled(!this.clearing)
            .backgroundColor(AhuColors.error).onClick(() => this.clearAll());
        }.width('100%').justifyContent(FlexAlign.End);
      }.width('86%').padding(24).backgroundColor(AhuColors.card).borderRadius(24)
        .shadow({ radius: 24, color: '#44000000' });
    }
  }
  .width('100%')
  .height('100%')
  .backgroundColor(AhuColors.pageBackground);
  }
}
