import { AhuColors, AhuTypography } from 'core_designsystem';
import { CampusItem, LostFoundType } from 'core_model';
import { ChipGroup, ChipGroupItemOptions, ChipItemStyle } from '@ohos.arkui.advanced.ChipGroup';
import { ChipSize } from '@ohos.arkui.advanced.Chip';

@CustomDialog
export struct LostFoundPublishDialog {
  controller?: CustomDialogController;
  campuses: Array<CampusItem> = [];
  types: Array<LostFoundType> = [];
  onPublish?: (linkman: string, phone: string, title: string, num1: string, campusId: string, typeId: string, state: string) => Promise<string> = undefined;

  @State linkman: string = '';
  @State phone: string = '';
  @State title: string = '';
  @State num1: string = '';
  @State publishCampusId: string = '';
  @State publishTypeId: string = '';
  @State publishState: string = '1';
  @State publishing: boolean = false;
  @State publishError: string = '';

  private chipItemStyle(): ChipItemStyle {
    return {
      size: ChipSize.NORMAL,
      backgroundColor: AhuColors.chipUnselected,
      fontColor: AhuColors.onSurface,
      selectedBackgroundColor: AhuColors.chipSelected,
      selectedFontColor: AhuColors.onPrimaryAction
    };
  }

  private async doPublish(): Promise<void> {
    if (this.linkman.trim().length === 0 || this.phone.trim().length === 0 || this.title.trim().length === 0 ||
      this.publishCampusId.length === 0 || this.publishTypeId.length === 0) {
      this.publishError = '请填写联系人、联系电话和描述，并选择校区与物品类型';
      return;
    }
    this.publishing = true;
    this.publishError = '';
    if (this.onPublish !== undefined) {
      const error = await this.onPublish(this.linkman.trim(), this.phone.trim(), this.title.trim(), this.num1.trim(),
        this.publishCampusId, this.publishTypeId, this.publishState);
      if (error.length > 0) {
        this.publishError = error;
        this.publishing = false;
        return;
      }
    }
    this.publishing = false;
    this.controller?.close();
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('发布信息')
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

      Scroll() {
        Column({ space: 12 }) {
          Text('当前版本与 Android 一致，暂不支持上传图片。')
            .fontSize(AhuTypography.label)
            .fontColor(AhuColors.onSurfaceSecondary);
          TextInput({ text: this.linkman, placeholder: '联系人（必填）' }).onChange((value: string) => this.linkman = value);
          TextInput({ text: this.phone, placeholder: '联系电话（必填）' }).type(InputType.PhoneNumber)
            .onChange((value: string) => this.phone = value);
          TextInput({ text: this.title, placeholder: '物品描述（必填）' }).onChange((value: string) => this.title = value);
          TextInput({ text: this.num1, placeholder: '编号/补充说明（选填）' }).onChange((value: string) => this.num1 = value);
          Text('选择校区').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium).fontColor(AhuColors.onSurface);
          Scroll() {
            ChipGroup({
              items: this.campuses.map((item: CampusItem): ChipGroupItemOptions => ({ label: { text: item.campusName } })),
              itemStyle: this.chipItemStyle(),
              selectedIndexes: (() => {
                const i = this.campuses.findIndex((c: CampusItem) => c.id === this.publishCampusId);
                return i >= 0 ? [i] : [];
              })(),
              multiple: false,
              chipGroupSpace: { itemSpace: 8 },
              onChange: (indexes: Array<number>) => {
                this.publishCampusId = indexes.length > 0 ? this.campuses[indexes[0]].id : '';
              }
            })
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off);
          Text('选择物品类型').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium).fontColor(AhuColors.onSurface);
          Scroll() {
            ChipGroup({
              items: this.types.map((item: LostFoundType): ChipGroupItemOptions => ({ label: { text: item.typeName } })),
              itemStyle: this.chipItemStyle(),
              selectedIndexes: (() => {
                const i = this.types.findIndex((t: LostFoundType) => t.typeId === this.publishTypeId);
                return i >= 0 ? [i] : [];
              })(),
              multiple: false,
              chipGroupSpace: { itemSpace: 8 },
              onChange: (indexes: Array<number>) => {
                this.publishTypeId = indexes.length > 0 ? this.types[indexes[0]].typeId : '';
              }
            })
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off);
          Text('信息类型').fontSize(AhuTypography.body).fontWeight(FontWeight.Medium).fontColor(AhuColors.onSurface);
          ChipGroup({
            items: [{ label: { text: '失物招领' } }, { label: { text: '寻物启事' } }],
            itemStyle: this.chipItemStyle(),
            selectedIndexes: [this.publishState === '1' ? 0 : 1],
            multiple: false,
            chipGroupSpace: { itemSpace: 8 },
            onChange: (indexes: Array<number>) => {
              this.publishState = indexes.length > 0 && indexes[0] === 0 ? '1' : '2';
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
      .constraintSize({ maxHeight: '65%' })
      .scrollBar(BarState.Off)
      .align(Alignment.Top);

      if (this.publishError.length > 0) {
        Text(this.publishError).fontSize(AhuTypography.label).fontColor(AhuColors.error).width('100%');
      }
      Button(this.publishing ? '发布中…' : '发布', { type: ButtonType.Capsule }).width('100%').enabled(!this.publishing)
        .fontColor(AhuColors.onPrimaryAction).backgroundColor(AhuColors.primaryAction).onClick(() => this.doPublish());
    }
    .width('90%')
    .constraintSize({ maxHeight: '88%' })
    .padding(24)
    .borderRadius(32)
    .backgroundColor(AhuColors.card)
    .alignItems(HorizontalAlign.Start);
  }
}
