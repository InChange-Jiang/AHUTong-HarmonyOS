import { AhuColors, AhuDimens } from '../theme/AhuTokens';

@Component
export struct AhuCard {
  @Prop cornerRadius: number = AhuDimens.cardCorner;
  @Prop containerColor: ResourceColor = AhuColors.card;

  @Builder
  private emptyContent() {}

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Column({ space: AhuDimens.contentHorizontal }) {
      this.content();
    }
    .width('100%')
    .padding({
      left: AhuDimens.cardPaddingHorizontal,
      right: AhuDimens.cardPaddingHorizontal,
      top: AhuDimens.cardPaddingVertical,
      bottom: AhuDimens.cardPaddingVertical
    })
    .backgroundColor(this.containerColor)
    .borderRadius(this.cornerRadius);
  }
}

@Component
export struct AhuInsetCard {
  @Prop cornerRadius: number = AhuDimens.cardCorner;
  @Prop containerColor: ResourceColor = AhuColors.card;

  @Builder
  private emptyContent() {}

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Row() {
      Column({ space: AhuDimens.contentHorizontal }) {
        this.content();
      }
      .width('100%')
      .padding({
        left: AhuDimens.cardPaddingHorizontal,
        right: AhuDimens.cardPaddingHorizontal,
        top: AhuDimens.cardPaddingVertical,
        bottom: AhuDimens.cardPaddingVertical
      })
      .backgroundColor(this.containerColor)
      .borderRadius(this.cornerRadius);
    }
    .width('100%')
    .padding({
      left: AhuDimens.contentHorizontal,
      right: AhuDimens.contentHorizontal
    });
  }
}
