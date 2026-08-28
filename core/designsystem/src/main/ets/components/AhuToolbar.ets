import { AhuColors, AhuDimens, AhuTypography } from '../theme/AhuTokens';
import { AhuAnimCurves, AhuAnimDurations } from '../theme/AhuAnimTokens';

@Component
export struct AhuToolbar {
  @Prop title: ResourceStr = '';
  @Prop subtitle: string = '';
  @Prop searchActive: boolean = false;
  @Prop searchText: string = '';
  @Prop searchable: boolean = false;
  @Prop searchPlaceholder: string = '搜索';
  @Prop filterable: boolean = false;
  @Prop filterActive: boolean = false;
  @Prop filterMenuItems: Array<string> = [];
  @Prop refreshable: boolean = false;
  @Prop refreshing: boolean = false;
  onBack: () => void = () => {};
  onSearchRequest?: () => void = undefined;
  onSearchInput?: (value: string) => void = undefined;
  onSearchExit?: () => void = undefined;
  onFilterClick?: () => void = undefined;
  onFilterSelect?: (index: number) => void = undefined;
  onRefresh?: () => void = undefined;

  @Builder
  private emptyContent() {}

  @BuilderParam actions: () => void = this.emptyContent;

  @Builder
  private backButton() {
    Button() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontColor([AhuColors.onSurface]);
    }
    .type(ButtonType.Circle)
    .width(40)
    .height(40)
    .backgroundColor(AhuColors.card)
    .onClick(() => { this.onBack(); });
  }

  @Builder
  private normalBar() {
    Row({ space: 12 }) {
      this.backButton();
      Column() {
        Text(this.title)
          .fontSize(AhuTypography.pageTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(AhuColors.onSurface)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(AhuTypography.label)
            .fontColor(AhuColors.onSurfaceSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 });
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Row({ space: 8 }) {
        if (this.searchable) {
          Button() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(20)
              .fontColor([AhuColors.onSurface]);
          }
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor(AhuColors.card)
          .onClick(() => {
            if (this.onSearchRequest !== undefined) this.onSearchRequest();
          });
        }
        if (this.filterable) {
          Button() {
            SymbolGlyph($r('sys.symbol.line_3_horizontal'))
              .fontSize(20)
              .fontColor([(this.filterActive ? AhuColors.primaryAction : AhuColors.onSurface) as ResourceColor]);
          }
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor(AhuColors.card)
          .bindMenu(this.filterMenuItems.map((label: string, index: number): MenuElement => ({
            value: label,
            action: () => {
              if (this.onFilterSelect !== undefined) this.onFilterSelect(index);
            }
          })))
          .onClick(() => {
            if (this.onFilterClick !== undefined) this.onFilterClick();
          });
        }
        if (this.refreshable) {
          Button() {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(20)
              .fontColor([AhuColors.onSurface])
              .rotate({ angle: this.refreshing ? 90 : 0 })
              .animation({ duration: AhuAnimDurations.short, curve: AhuAnimCurves.default });
          }
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor(AhuColors.card)
          .opacity(this.refreshing ? 0.6 : 1)
          .enabled(!this.refreshing)
          .onClick(() => {
            if (this.onRefresh !== undefined) this.onRefresh();
          });
        }
        Row({ space: 8 }) { this.actions(); }
      }
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -8 }))
        .animation({ duration: AhuAnimDurations.short, curve: AhuAnimCurves.default }),
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -8 }))
        .animation({ duration: AhuAnimDurations.short, curve: AhuAnimCurves.default })
    ));
  }

  @Builder
  private searchBar() {
    Row({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([AhuColors.onSurfaceSecondary]);
        TextInput({ text: this.searchText, placeholder: this.searchPlaceholder })
          .layoutWeight(1)
          .fontColor(AhuColors.onSurface)
          .placeholderColor(AhuColors.onSurfaceSecondary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            if (this.onSearchInput !== undefined) this.onSearchInput(value);
          });
      }
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(20)
      .backgroundColor(AhuColors.card)
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center);
      Text('取消')
        .fontSize(16)
        .fontColor(AhuColors.primaryAction)
        .onClick(() => {
          if (this.onSearchExit !== undefined) this.onSearchExit();
        });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 8 }))
        .animation({ duration: AhuAnimDurations.short, curve: AhuAnimCurves.default }),
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 8 }))
        .animation({ duration: AhuAnimDurations.short, curve: AhuAnimCurves.default })
    ));
  }

  build() {
    Column() {
      if (this.searchActive) {
        this.searchBar();
      } else {
        this.normalBar();
      }
    }
    .width('100%')
    .padding({
      left: AhuDimens.contentHorizontal,
      right: AhuDimens.contentHorizontal,
      top: AhuDimens.titleTop
    });
  }
}
