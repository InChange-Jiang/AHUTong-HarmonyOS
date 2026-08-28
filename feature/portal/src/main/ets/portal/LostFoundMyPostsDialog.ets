import { AhuColors, AhuTypography } from 'core_designsystem';
import { LostFoundItem } from 'core_model';

@CustomDialog
export struct LostFoundMyPostsDialog {
  controller?: CustomDialogController;
  posts: Array<LostFoundItem> = [];
  onDelete?: (id: string) => Promise<string> = undefined;

  @State dialogPosts: Array<LostFoundItem> = [];
  @State deleteTarget?: LostFoundItem = undefined;
  @State deleting: boolean = false;
  @State deleteError: string = '';

  aboutToAppear(): void {
    this.dialogPosts = [...this.posts];
    this.deleteTarget = undefined;
    this.deleting = false;
    this.deleteError = '';
  }

  private async doDelete(): Promise<void> {
    const target = this.deleteTarget;
    if (target === undefined || this.deleting) return;
    this.deleting = true;
    this.deleteError = '';
    if (this.onDelete !== undefined) {
      const error = await this.onDelete(target.id);
      if (error.length > 0) {
        this.deleteError = error;
        this.deleting = false;
        return;
      }
    }
    this.dialogPosts = this.dialogPosts.filter((item: LostFoundItem) => item.id !== target.id);
    this.deleteTarget = undefined;
    this.deleting = false;
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('我的帖子')
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

      Stack({ alignContent: Alignment.Center }) {
        if (this.dialogPosts.length === 0) {
          Column({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.archivebox')).fontSize(40).fontColor([AhuColors.onSurfaceSecondary]);
            Text('当前列表中没有由你发布的帖子')
              .fontSize(AhuTypography.label)
              .fontColor(AhuColors.onSurfaceSecondary);
          }
          .width('100%')
          .padding({ top: 40, bottom: 40 })
          .justifyContent(FlexAlign.Center);
        } else {
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.dialogPosts, (item: LostFoundItem) => {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(item.title).fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).maxLines(2);
                    Text(item.createtime ?? '').fontSize(AhuTypography.label)
                      .fontColor(AhuColors.onSurfaceSecondary);
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);
                  Button('删除', { type: ButtonType.Capsule }).fontColor(AhuColors.error)
                    .backgroundColor(AhuColors.chipUnselected)
                    .onClick(() => {
                      this.deleteError = '';
                      this.deleteTarget = item;
                    });
                }
                .width('100%')
                .padding(12)
                .backgroundColor(AhuColors.cardStrong)
                .borderRadius(16);
              }, (item: LostFoundItem) => item.id);
            }
            .width('100%');
          }
          .width('100%')
          .constraintSize({ maxHeight: '60%' })
          .scrollBar(BarState.Auto)
          .align(Alignment.Top);
        }

        if (this.deleteTarget) {
          Column() {
            Column({ space: 18 }) {
              Row() {
                Text('确认删除')
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
                .onClick(() => {
                  this.deleteTarget = undefined;
                  this.deleteError = '';
                });
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);
              Text(`确定删除“${this.deleteTarget.title}”吗？删除后无法恢复。`)
                .fontSize(AhuTypography.body)
                .fontColor(AhuColors.onSurface)
                .width('100%');
              if (this.deleteError.length > 0) {
                Text(this.deleteError).fontSize(AhuTypography.label).fontColor(AhuColors.error).width('100%');
              }
              Row({ space: 10 }) {
                Button('取消', { type: ButtonType.Capsule }).layoutWeight(1).enabled(!this.deleting)
                  .fontColor(AhuColors.onSurface).backgroundColor(AhuColors.chipUnselected)
                  .onClick(() => {
                    this.deleteTarget = undefined;
                    this.deleteError = '';
                  });
                Button(this.deleting ? '删除中…' : '删除', { type: ButtonType.Capsule }).layoutWeight(1)
                  .enabled(!this.deleting)
                  .fontColor(AhuColors.onPrimaryAction).backgroundColor(AhuColors.error)
                  .onClick(() => this.doDelete());
              }
              .width('100%');
            }
            .width('86%')
            .padding(24)
            .borderRadius(32)
            .backgroundColor(AhuColors.card)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#66000000');
        }
      }
      .width('100%');
    }
    .width('90%')
    .constraintSize({ maxHeight: '88%' })
    .padding(24)
    .borderRadius(32)
    .backgroundColor(AhuColors.card)
    .alignItems(HorizontalAlign.Start);
  }
}
