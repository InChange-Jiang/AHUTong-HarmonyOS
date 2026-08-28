import { AhuColors, AhuTypography } from '../theme/AhuTokens';
import { Chip, ChipSize } from '@ohos.arkui.advanced.Chip';

@Component
export struct AhuPrimaryButton {
  @Prop text: string = '';
  @Prop isEnabled: boolean = true;
  clickAction: () => void = () => {};

  build() {
    Button(this.text, { type: ButtonType.Capsule, stateEffect: true })
      .fontSize(AhuTypography.body)
      .fontWeight(FontWeight.Medium)
      .fontColor(AhuColors.onPrimaryAction)
      .backgroundColor(AhuColors.primaryAction)
      .opacity(this.isEnabled ? 1 : 0.4)
      .enabled(this.isEnabled)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => this.clickAction());
  }
}

@Component
export struct AhuChip {
  @Prop text: string = '';
  @Prop selected: boolean = false;
  clickAction: () => void = () => {};

  build() {
    Chip({
      label: {
        text: this.text,
        fontSize: AhuTypography.label,
        fontColor: this.selected ? AhuColors.onPrimaryAction : AhuColors.onSurface,
        activatedFontColor: AhuColors.onPrimaryAction
      },
      activated: this.selected,
      backgroundColor: AhuColors.chipUnselected,
      activatedBackgroundColor: AhuColors.chipSelected,
      borderRadius: 24,
      size: ChipSize.NORMAL,
      onClicked: (): void => this.clickAction()
    });
  }
}
