import { AhuChip, AhuColors, AhuTypography } from 'core_designsystem';
import { CampusItem, LostFoundType } from 'core_model';
import { ChipGroup, ChipGroupItemOptions, ChipItemStyle } from '@ohos.arkui.advanced.ChipGroup';
import { ChipSize } from '@ohos.arkui.advanced.Chip';

@CustomDialog
export struct LostFoundFilterDialog {
  controller?: CustomDialogController;
  campuses: Array<CampusItem> = [];
  types: Array<LostFoundType> = [];
  selectedCampusId: string = '';
  selectedTypeId: string = '';
  onApply?: (campusId: string, typeId: string) => void = undefined;

  @State dialogCampusId: string = '';
  @State dialogTypeId: string = '';

  aboutToAppear(): void {
    this.dialogCampusId = this.selectedCampusId;
    this.dialogTypeId = this.selectedTypeId;
  }

  private reset(): void {
    this.dialogCampusId = '';
    this.dialogTypeId = '';
  }

  private apply(): void {
    if (this.onApply !== undefined) {
      this.onApply(this.dialogCampusId, this.dialogTypeId);
    }
    this.controller?.close();
  }

  private chipItemStyle(): ChipItemStyle {
    return {
      size: ChipSize.NORMAL,
      backgroundColor: AhuColors.chipUnselected,
      fontColor: AhuColors.onSurface,
      selectedBackgroundColor: AhuColors.chipSelected,
      selectedFontColor: AhuColors.onPrimaryAction
    };
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('筛选')
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
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Text('校区').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface);
            ChipGroup({
              items: [
                { label: { text: '全部校区' } },
                ...this.campuses.map((item: CampusItem): ChipGroupItemOptions => ({ label: { text: item.campusName } }))
              ],
              itemStyle: this.chipItemStyle(),
              selectedIndexes: this.dialogCampusId.length === 0 ? [0] :
                (() => {
                  const idx = this.campuses.findIndex((c: CampusItem) => c.id === this.dialogCampusId);
                  return idx >= 0 ? [idx + 1] : [];
                })(),
              multiple: false,
              chipGroupSpace: { itemSpace: 8 },
              onChange: (indexes: Array<number>) => {
                if (indexes.length === 0 || indexes[0] === 0) this.dialogCampusId = '';
                else this.dialogCampusId = this.campuses[indexes[0] - 1].id;
              }
            })
          }
          .alignItems(HorizontalAlign.Start);

          Column({ space: 12 }) {
            Text('物品类型').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface);
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              AhuChip({
                text: '全部类型',
                selected: this.dialogTypeId.length === 0,
                clickAction: (): void => { this.dialogTypeId = ''; }
              }).margin({ right: 8, bottom: 8 });
              ForEach(this.types, (item: LostFoundType) => {
                AhuChip({
                  text: item.typeName,
                  selected: this.dialogTypeId === item.typeId,
                  clickAction: (): void => { this.dialogTypeId = item.typeId; }
                }).margin({ right: 8, bottom: 8 });
              }, (item: LostFoundType) => item.typeId);
            }
          }
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%');
      }
      .constraintSize({ maxHeight: '60%' })
      .scrollBar(BarState.Off)
      .align(Alignment.Top);

      Row({ space: 12 }) {
        Button('重置', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .backgroundColor(AhuColors.cardStrong)
          .fontColor(AhuColors.onSurface)
          .onClick(() => this.reset());
        Button('确定', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .backgroundColor(AhuColors.primaryAction)
          .fontColor(Color.White)
          .onClick(() => this.apply());
      }
      .width('100%');
    }
    .width('88%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(AhuColors.card)
    .alignItems(HorizontalAlign.Start);
  }
}
