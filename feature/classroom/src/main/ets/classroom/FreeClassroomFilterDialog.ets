import { AhuChip, AhuColors, AhuInsetCard, AhuTypography } from 'core_designsystem';
import { AcademicCrawlerClient } from 'data_crawler';
import { AhuCache } from 'core_datastore';
import { ChipGroup, ChipGroupItemOptions, ChipItemStyle } from '@ohos.arkui.advanced.ChipGroup';
import { ChipSize } from '@ohos.arkui.advanced.Chip';

export interface Building { id: number; nameZh: string; }

@CustomDialog
export struct FreeClassroomFilterDialog {
  controller?: CustomDialogController;
  private readonly client: AcademicCrawlerClient = new AcademicCrawlerClient();
  campusId: number = 1;
  buildings: Array<Building> = [];
  selectedBuildingIds: Array<number> = [];
  selectedUnits: Array<number> = [];
  startDate: string = '';
  endDate: string = '';
  onApply?: (campusId: number, selectedBuildings: Array<number>, selectedUnits: Array<number>, startDate: string, endDate: string) => void = undefined;

  @State dialogCampusId: number = 1;
  @State dialogBuildings: Array<Building> = [];
  @State dialogSelectedBuildings: Array<number> = [];
  @State dialogSelectedUnits: Array<number> = [];
  @State dialogStartDate: string = '';
  @State dialogEndDate: string = '';
  @State loadingBuildings: boolean = false;

  aboutToAppear(): void {
    this.dialogCampusId = this.campusId;
    this.dialogBuildings = this.buildings;
    this.dialogSelectedBuildings = [...this.selectedBuildingIds];
    this.dialogSelectedUnits = [...this.selectedUnits];
    this.dialogStartDate = this.startDate;
    this.dialogEndDate = this.endDate;
  }

  private formatDate(date: Date): string {
    return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`;
  }

  private async loadBuildings(): Promise<void> {
    this.loadingBuildings = true;
    this.dialogBuildings = [];
    this.dialogSelectedBuildings = [];
    if (AhuCache.getMockData()) {
      const scenario = AhuCache.getMockScenario();
      if (scenario !== 'network_error' && scenario !== 'expired_login') {
        if (scenario !== 'empty_campus' && !(scenario === 'longhe_only' && this.dialogCampusId !== 2)) {
          const prefix = this.dialogCampusId === 2 ? '龙河' : '磬苑';
          this.dialogBuildings = [
            { id: this.dialogCampusId * 100 + 1, nameZh: `${prefix}教学主楼` },
            { id: this.dialogCampusId * 100 + 2, nameZh: `${prefix}公共教学楼` }
          ];
        }
      }
      this.loadingBuildings = false;
      return;
    }
    const result = await this.client.getJson<Array<Building>>(
      `https://jw.ahu.edu.cn/student/ws/room/get-buildings?campusId=${this.dialogCampusId}&hasDataPermission=false`);
    if (result.isSuccess) {
      this.dialogBuildings = (result.data ?? []).sort((a: Building, b: Building): number => a.nameZh.localeCompare(b.nameZh));
    }
    this.loadingBuildings = false;
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

  private toggleBuilding(id: number): void {
    this.dialogSelectedBuildings = this.dialogSelectedBuildings.includes(id)
      ? this.dialogSelectedBuildings.filter((value: number): boolean => value !== id)
      : [...this.dialogSelectedBuildings, id];
  }

  private toggleUnit(unit: number): void {
    this.dialogSelectedUnits = this.dialogSelectedUnits.includes(unit)
      ? this.dialogSelectedUnits.filter((value: number): boolean => value !== unit)
      : [...this.dialogSelectedUnits, unit];
  }

  private toggleRange(start: number, end: number): void {
    const range = Array.from({ length: end - start + 1 }, (_: Object, index: number) => start + index);
    const selected = range.every((unit: number): boolean => this.dialogSelectedUnits.includes(unit));
    this.dialogSelectedUnits = selected
      ? this.dialogSelectedUnits.filter((unit: number): boolean => !range.includes(unit))
      : Array.from(new Set([...this.dialogSelectedUnits, ...range])).sort((a: number, b: number): number => a - b);
  }

  private quickDate(offset: number): void {
    const date = new Date();
    date.setDate(date.getDate() + offset);
    this.dialogStartDate = this.formatDate(date);
    this.dialogEndDate = this.dialogStartDate;
  }

  private chooseDate(isStart: boolean): void {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const minimum = isStart ? today : new Date(`${this.dialogStartDate}T00:00:00`);
    const selected = new Date(`${isStart ? this.dialogStartDate : this.dialogEndDate}T00:00:00`);
    this.getUIContext().showDatePickerDialog({
      start: minimum,
      end: new Date(today.getFullYear() + 5, 11, 31),
      selected: selected,
      onDateAccept: (date: Date) => {
        const value = this.formatDate(date);
        if (isStart) {
          this.dialogStartDate = value;
          if (new Date(`${this.dialogEndDate}T00:00:00`).getTime() < date.getTime()) this.dialogEndDate = value;
        } else {
          this.dialogEndDate = value;
        }
      }
    });
  }

  private reset(): void {
    this.dialogCampusId = 1;
    this.loadBuildings();
    this.dialogSelectedUnits = [];
    const today = this.formatDate(new Date());
    this.dialogStartDate = today;
    this.dialogEndDate = today;
  }

  private apply(): void {
    if (this.onApply !== undefined) {
      this.onApply(this.dialogCampusId, this.dialogSelectedBuildings, this.dialogSelectedUnits, this.dialogStartDate, this.dialogEndDate);
    }
    this.controller?.close();
  }

  @Builder
  private chipRow(items: Array<number>) {
    Scroll() {
      ChipGroup({
        items: items.map((unit: number): ChipGroupItemOptions => ({ label: { text: `第 ${unit} 节` } })),
        itemStyle: this.chipItemStyle(),
        selectedIndexes: items
          .filter((unit: number) => this.dialogSelectedUnits.includes(unit))
          .map((unit: number) => items.indexOf(unit)),
        multiple: true,
        chipGroupSpace: { itemSpace: 8 },
        onChange: (indexes: Array<number>) => {
          this.dialogSelectedUnits = indexes.map((i: number) => items[i]);
        }
      })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off);
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('筛选空闲教室')
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
          AhuInsetCard() {
            Column({ space: 12 }) {
              Text('选择校区').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface);
              ChipGroup({
                items: [
                  { label: { text: '磬苑校区' } },
                  { label: { text: '龙河校区' } }
                ],
                itemStyle: this.chipItemStyle(),
                selectedIndexes: [this.dialogCampusId - 1],
                multiple: false,
                chipGroupSpace: { itemSpace: 8 },
                onChange: (indexes: Array<number>) => {
                  const campus = indexes.length > 0 ? indexes[0] + 1 : 1;
                  if (campus !== this.dialogCampusId) {
                    this.dialogCampusId = campus;
                    this.loadBuildings();
                  }
                }
              })
            }
            .alignItems(HorizontalAlign.Start);
          }

          AhuInsetCard() {
            Column({ space: 12 }) {
              Text('选择教学楼（不选即全部）').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface);
              if (this.loadingBuildings) {
                LoadingProgress().width(24).height(24).color(AhuColors.primaryAction);
              } else if (this.dialogBuildings.length === 0) {
                Text('当前校区暂无教学楼数据').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
              } else {
                Scroll() {
                  ChipGroup({
                    items: this.dialogBuildings.map((item: Building): ChipGroupItemOptions => ({ label: { text: item.nameZh } })),
                    itemStyle: this.chipItemStyle(),
                    selectedIndexes: this.dialogSelectedBuildings
                      .filter((id: number) => this.dialogBuildings.some((b: Building) => b.id === id))
                      .map((id: number) => this.dialogBuildings.findIndex((b: Building) => b.id === id)),
                    multiple: true,
                    chipGroupSpace: { itemSpace: 8 },
                    onChange: (indexes: Array<number>) => {
                      this.dialogSelectedBuildings = indexes.map((i: number) => this.dialogBuildings[i].id);
                    }
                  })
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off);
              }
            }
            .alignItems(HorizontalAlign.Start);
          }

          AhuInsetCard() {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('选择节次').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface).layoutWeight(1);
                AhuChip({
                  text: '上午',
                  selected: [1, 2, 3, 4, 5].every((v: number): boolean => this.dialogSelectedUnits.includes(v)),
                  clickAction: () => this.toggleRange(1, 5)
                });
                AhuChip({
                  text: '下午',
                  selected: [6, 7, 8, 9, 10].every((v: number): boolean => this.dialogSelectedUnits.includes(v)),
                  clickAction: () => this.toggleRange(6, 10)
                });
                AhuChip({
                  text: '晚上',
                  selected: [11, 12, 13].every((v: number): boolean => this.dialogSelectedUnits.includes(v)),
                  clickAction: () => this.toggleRange(11, 13)
                });
              }
              this.chipRow(Array.from({ length: 13 }, (_: Object, i: number) => i + 1));
            }
            .alignItems(HorizontalAlign.Start);
          }

          AhuInsetCard() {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('查询日期').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface).layoutWeight(1);
                ChipGroup({
                  items: [{ label: { text: '今天' } }, { label: { text: '明天' } }],
                  itemStyle: this.chipItemStyle(),
                  selectedIndexes: this.dialogStartDate === this.formatDate(new Date()) && this.dialogEndDate === this.dialogStartDate ? [0] :
                    (this.dialogStartDate === this.formatDate(new Date(Date.now() + 86_400_000)) && this.dialogEndDate === this.dialogStartDate ? [1] : []),
                  multiple: false,
                  chipGroupSpace: { itemSpace: 8 },
                  onChange: (indexes: Array<number>) => {
                    if (indexes.length > 0) this.quickDate(indexes[0]);
                  }
                })
              }
              Scroll() {
                Row({ space: 8 }) {
                  AhuChip({
                    text: `开始 ${this.dialogStartDate}`,
                    selected: true,
                    clickAction: () => this.chooseDate(true)
                  });
                  AhuChip({
                    text: `结束 ${this.dialogEndDate}`,
                    selected: true,
                    clickAction: () => this.chooseDate(false)
                  });
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off);
              Text('可选择今天起五年内的日期范围').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
            }
            .alignItems(HorizontalAlign.Start);
          }
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
    .width('90%')
    .padding(24)
    .borderRadius(32)
    .backgroundColor(AhuColors.card)
    .alignItems(HorizontalAlign.Start);
  }
}
