import { AhuColors, AhuDimens, AhuInsetCard, AhuToolbar, AhuTypography } from 'core_designsystem';
import { CampusItem, LostFoundItem, LostFoundPublishRequest, LostFoundType } from 'core_model';
import { LostFoundRepository, getLostFoundRepository } from 'data_portal';
import { BackPressDispatcher } from 'core_common';
import { LostFoundFilterDialog } from './LostFoundFilterDialog';
import { LostFoundMyPostsDialog } from './LostFoundMyPostsDialog';
import { LostFoundPublishDialog } from './LostFoundPublishDialog';

@Component
export struct LostFoundPage {
  private readonly repository: LostFoundRepository = getLostFoundRepository();
  @State state: number = 1;
  @State page: number = 1;
  @State pages: number = 1;
  @State items: Array<LostFoundItem> = [];
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State selected?: LostFoundItem = undefined;
  @State campuses: Array<CampusItem> = [];
  @State types: Array<LostFoundType> = [];
  @State searchExpanded: boolean = false;
  @State query: string = '';
  @State selectedCampusId: string = '';
  @State selectedTypeId: string = '';
  @State imageViewerIndex: number = -1;
  onBack: () => void = () => {};

  private publishDialogController: CustomDialogController = new CustomDialogController({
    builder: LostFoundPublishDialog({
      campuses: this.campuses,
      types: this.types,
      onPublish: async (linkman: string, phone: string, title: string, num1: string,
        campusId: string, typeId: string, state: string): Promise<string> => {
        const request: LostFoundPublishRequest = { imgs: [], linkman: linkman, phone: phone, title: title, num1: num1,
          campusid: campusId, typeid: typeId, state: state, auditresult: 1 };
        const result = await this.repository.publish(request);
        if (!result.isSuccess) return result.error?.message ?? '发布失败';
        this.state = Number(state);
        await this.load(true);
        return '';
      }
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    autoCancel: true,
    offset: { dx: 0, dy: 0 }
  });

  private myPostsDialogController: CustomDialogController = new CustomDialogController({
    builder: LostFoundMyPostsDialog({
      posts: this.myPosts(),
      onDelete: async (id: string): Promise<string> => {
        const result = await this.repository.delete(id);
        if (!result.isSuccess) return result.error?.message ?? '删除失败';
        this.items = this.items.filter((item: LostFoundItem) => item.id !== id);
        return '';
      }
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    autoCancel: true,
    offset: { dx: 0, dy: 0 }
  });

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: LostFoundFilterDialog({
      campuses: this.campuses,
      types: this.types,
      selectedCampusId: this.selectedCampusId,
      selectedTypeId: this.selectedTypeId,
      onApply: (campusId: string, typeId: string) => {
        this.selectedCampusId = campusId;
        this.selectedTypeId = typeId;
      }
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    autoCancel: true,
    offset: { dx: 0, dy: 0 }
  });

  aboutToAppear(): void {
    BackPressDispatcher.register('lost_found_page', () => this.handleBackPress());
    this.load(true); this.loadPublishOptions();
  }
  aboutToDisappear(): void { BackPressDispatcher.unregister('lost_found_page'); }

  private handleBackPress(): boolean {
    if (this.imageViewerIndex >= 0) { this.imageViewerIndex = -1; return true; }
    if (this.selected) { this.selected = undefined; return true; }
    if (this.searchExpanded) { this.searchExpanded = false; this.query = ''; return true; }
    this.onBack();
    return true;
  }

  private async loadPublishOptions(): Promise<void> {
    const campusResult = await this.repository.getCampuses();
    if (campusResult.isSuccess && campusResult.data) this.campuses = campusResult.data;
    const typeResult = await this.repository.getTypes();
    if (typeResult.isSuccess && typeResult.data) this.types = typeResult.data;
  }

  private myPosts(): Array<LostFoundItem> {
    const userId = this.repository.currentUserId();
    return this.items.filter((item: LostFoundItem) => item.pubuser?.idNumber === userId);
  }

  private async load(refresh: boolean): Promise<void> {
    if (refresh) { this.loading = true; this.page = 1; } else this.loadingMore = true;
    this.error = '';
    const target = refresh ? 1 : this.page + 1;
    const response = await this.repository.getList(target, 20, this.state);
    if (response.isSuccess && response.data) {
      this.items = refresh ? response.data.object.list : this.items.concat(response.data.object.list);
      this.page = response.data.object.pageNum; this.pages = Math.max(1, response.data.object.pages);
    } else this.error = response.error?.message ?? '失物招领加载失败';
    this.loading = false; this.loadingMore = false;
  }

  private switchState(value: number): void {
    if (this.state === value) return;
    this.state = value; this.items = []; this.load(true);
  }

  private imageUrl(item: LostFoundItem): string {
    const path = item.imgs.length > 0 ? item.imgs[0].imgPath : '';
    if (path.length === 0 || /^https?:\/\//.test(path)) return path;
    return `https://adwmh.ahu.edu.cn${path.startsWith('/') ? '' : '/'}${path}`;
  }

  private imageUrlAt(item: LostFoundItem, index: number): string {
    if (index < 0 || index >= item.imgs.length) return '';
    const path = item.imgs[index].imgPath;
    if (/^https?:\/\//.test(path)) return path;
    return `https://adwmh.ahu.edu.cn${path.startsWith('/') ? '' : '/'}${path}`;
  }

  private hasFilter(): boolean {
    return this.selectedCampusId.length > 0 || this.selectedTypeId.length > 0;
  }

  private filteredItems(): Array<LostFoundItem> {
    const query = this.query.trim().toLowerCase();
    return this.items.filter((item: LostFoundItem) => {
      if (this.selectedCampusId.length > 0 && item.campusid !== this.selectedCampusId) return false;
      if (this.selectedTypeId.length > 0 && item.typeid !== this.selectedTypeId) return false;
      if (query.length === 0) return true;
      const values = [item.title, item.linkman, item.phone, item.campusName, item.lostType?.typeName,
        item.pubuser?.userName, item.num1, item.createtime];
      return values.some((value?: string) => (value ?? '').toLowerCase().includes(query));
    });
  }

  @Builder
  private detail(item: LostFoundItem) {
    Column({ space: 14 }) {
      Row() {
        Text(item.title).fontSize(AhuTypography.sectionTitle).fontWeight(FontWeight.Bold).layoutWeight(1);
        Button('×', { type: ButtonType.Circle }).width(38).height(38)
          .backgroundColor(AhuColors.chipUnselected).fontColor(AhuColors.onSurface).onClick(() => this.selected = undefined);
      }.width('100%');
      if (this.imageUrl(item).length > 0) Image(this.imageUrl(item)).width('100%').height(220)
        .objectFit(ImageFit.Contain).backgroundColor(AhuColors.cardStrong).borderRadius(18)
        .onClick(() => this.imageViewerIndex = 0);
      Text(`${item.state === 1 ? '招领物品' : '寻找物品'} · ${item.lostType?.typeName ?? '未分类'}`)
        .fontSize(AhuTypography.body).fontColor(AhuColors.onSurfaceSecondary);
      Text(`校区：${item.campusName ?? '未填写'}`).fontSize(AhuTypography.body);
      Text(`数量/说明：${item.num1 ?? '未填写'}`).fontSize(AhuTypography.body);
      Text(`联系人：${item.linkman ?? item.pubuser?.userName ?? '未填写'}`).fontSize(AhuTypography.body);
      Text(`电话：${item.phone ?? item.pubuser?.mobile ?? '未填写'}`).fontSize(AhuTypography.body);
      Text(`发布时间：${item.createtime ?? '未知'}`).fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
    }.width('90%').height('82%').padding(24).backgroundColor(AhuColors.card).borderRadius(28)
      .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private imageViewer(item: LostFoundItem) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.imageUrlAt(item, this.imageViewerIndex)).width('100%').height('100%').objectFit(ImageFit.Contain);
      Row() {
        Button('‹', { type: ButtonType.Circle }).width(48).height(48).fontSize(30)
          .visibility(this.imageViewerIndex > 0 ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => this.imageViewerIndex -= 1);
        Blank();
        Button('›', { type: ButtonType.Circle }).width(48).height(48).fontSize(30)
          .visibility(this.imageViewerIndex < item.imgs.length - 1 ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => this.imageViewerIndex += 1);
      }.width('94%');
      Button('×', { type: ButtonType.Circle }).width(44).height(44).fontSize(24).position({ top: 28, right: 20 })
        .onClick(() => this.imageViewerIndex = -1);
      Text(`${this.imageViewerIndex + 1} / ${item.imgs.length}`).fontColor('#FFFFFF')
        .position({ bottom: 28, left: '44%' });
    }.width('100%').height('100%').backgroundColor('#EE000000');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 16 }) {
        AhuToolbar({
          title: '失物招领',
          searchable: true,
          searchActive: this.searchExpanded,
          searchText: this.query,
          searchPlaceholder: '搜索联系人、电话、描述、校区等',
          onSearchRequest: (): void => { this.searchExpanded = true; },
          onSearchInput: (value: string): void => { this.query = value; },
          onSearchExit: (): void => { this.searchExpanded = false; this.query = ''; },
          filterable: true,
          filterActive: this.hasFilter(),
          onFilterClick: (): void => this.filterDialogController.open(),
          onBack: (): void => this.onBack()
        }) {
          Button() {
            SymbolGlyph($r('sys.symbol.more')).fontSize(20).fontColor([AhuColors.onSurface]);
          }
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor(AhuColors.card)
          .bindMenu([
            { value: '发布', action: (): void => { this.publishDialogController.open(); } },
            { value: '我的帖子', action: (): void => { this.myPostsDialogController.open(); } },
            { value: '刷新', action: (): void => { this.load(true); } }
          ]);
        }
        Scroll() {
          Column({ space: AhuDimens.sectionSpacing }) {
            Row({ space: 8 }) {
              Button('失物招领', { type: ButtonType.Capsule }).layoutWeight(1)
                .fontColor(this.state === 1 ? AhuColors.onPrimaryAction : AhuColors.onSurface)
                .backgroundColor(this.state === 1 ? AhuColors.primaryAction : AhuColors.chipUnselected)
                .onClick(() => this.switchState(1));
              Button('寻物启事', { type: ButtonType.Capsule }).layoutWeight(1)
                .fontColor(this.state === 2 ? AhuColors.onPrimaryAction : AhuColors.onSurface)
                .backgroundColor(this.state === 2 ? AhuColors.primaryAction : AhuColors.chipUnselected)
                .onClick(() => this.switchState(2));
            }.width('100%').padding({ left: 16, right: 16 });
            Text(this.query.trim().length > 0 ? `“${this.query.trim()}”找到 ${this.filteredItems().length} 条` :
              `共 ${this.filteredItems().length} 条`).fontSize(AhuTypography.body).fontWeight(FontWeight.Medium)
              .padding({ left: 18, right: 18 });
        if (this.loading) {
          Column({ space: 12 }) { LoadingProgress().width(48).height(48).color(AhuColors.primaryAction); Text('正在加载…'); }
            .width('100%').padding(48);
        } else if (this.items.length === 0) {
          AhuInsetCard() { Text(this.error.length > 0 ? this.error : '暂无内容').fontColor(AhuColors.onSurfaceSecondary); }
        } else if (this.filteredItems().length === 0) {
          AhuInsetCard() { Text('没有符合筛选条件的内容').fontColor(AhuColors.onSurfaceSecondary); }
        } else {
          ForEach(this.filteredItems(), (item: LostFoundItem) => {
            AhuInsetCard() {
              Row({ space: 14 }) {
                if (this.imageUrl(item).length > 0) Image(this.imageUrl(item)).width(88).height(88)
                  .objectFit(ImageFit.Cover).borderRadius(16).backgroundColor(AhuColors.cardStrong);
                Column({ space: 7 }) {
                  Text(item.title).fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).maxLines(2);
                  Text(`${item.lostType?.typeName ?? '未分类'} · ${item.campusName ?? '未知校区'}`)
                    .fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary).maxLines(1);
                  Text(item.createtime ?? '').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
                }.layoutWeight(1).alignItems(HorizontalAlign.Start);
              }.width('100%').onClick(() => this.selected = item);
            }
          }, (item: LostFoundItem) => item.id);
          if (this.page < this.pages) Button(this.loadingMore ? '加载中…' : '加载更多', { type: ButtonType.Capsule })
            .enabled(!this.loadingMore).alignSelf(ItemAlign.Center).backgroundColor(AhuColors.chipUnselected)
            .fontColor(AhuColors.onSurface).onClick(() => this.load(false));
        }
        if (this.error.length > 0 && this.items.length > 0) Text(this.error).fontColor(AhuColors.error).padding(16);
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off);
      }
      .width('100%')
      .height('100%');
      if (this.selected) {
        Column() { this.detail(this.selected); }.width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor('#66000000');
      }
      if (this.selected && this.imageViewerIndex >= 0) this.imageViewer(this.selected);
    }.width('100%').height('100%').backgroundColor(AhuColors.pageBackground);
  }
}
