import { AhuColors, AhuTypography } from 'core_designsystem';

@CustomDialog
export struct WeatherSettingsDialog {
  controller?: CustomDialogController;
  showOnHome: boolean = true;
  showLocation: boolean = true;
  showTemperature: boolean = true;
  showCondition: boolean = true;
  showAqi: boolean = true;
  onSettingChange?: (key: string, value: boolean) => void = undefined;

  @State dShowOnHome: boolean = true;
  @State dShowLocation: boolean = true;
  @State dShowTemperature: boolean = true;
  @State dShowCondition: boolean = true;
  @State dShowAqi: boolean = true;

  aboutToAppear(): void {
    this.dShowOnHome = this.showOnHome;
    this.dShowLocation = this.showLocation;
    this.dShowTemperature = this.showTemperature;
    this.dShowCondition = this.showCondition;
    this.dShowAqi = this.showAqi;
  }

  private updateState(key: string, value: boolean): void {
    if (key === 'showOnHome') this.dShowOnHome = value;
    else if (key === 'showLocation') this.dShowLocation = value;
    else if (key === 'showTemperature') this.dShowTemperature = value;
    else if (key === 'showCondition') this.dShowCondition = value;
    else if (key === 'showAqi') this.dShowAqi = value;
  }

  @Builder
  private setting(label: string, key: string, value: boolean) {
    Row() {
      Text(label).fontSize(AhuTypography.body).fontColor(AhuColors.onSurface).layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: value }).onChange((on: boolean) => {
        if (this.onSettingChange !== undefined) this.onSettingChange(key, on);
        this.updateState(key, on);
      });
    }.width('100%').padding({ top: 2, bottom: 2 });
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('天气设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AhuColors.onSurface)
          .layoutWeight(1);
        Button() {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([AhuColors.onSurfaceSecondary]);
        }
        .type(ButtonType.Circle)
        .width(32)
        .height(32)
        .backgroundColor(AhuColors.cardStrong)
        .onClick(() => this.controller?.close());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text('选择要在首页卡片上显示的信息：')
        .fontSize(AhuTypography.label)
        .fontColor(AhuColors.onSurfaceSecondary)
        .width('100%');

      this.setting('在首页显示天气', 'showOnHome', this.dShowOnHome);
      this.setting('显示城市名', 'showLocation', this.dShowLocation);
      this.setting('显示温度', 'showTemperature', this.dShowTemperature);
      this.setting('显示天气状况', 'showCondition', this.dShowCondition);
      this.setting('显示空气质量', 'showAqi', this.dShowAqi);
    }
    .width('90%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(AhuColors.card)
    .alignItems(HorizontalAlign.Start);
  }
}
