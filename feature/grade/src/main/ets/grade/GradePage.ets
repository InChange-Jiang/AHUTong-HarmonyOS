import { AhuChip, AhuColors, AhuEmptyState, AhuInsetCard, AhuLoading, AhuTypography } from 'core_designsystem';
import { GpaRankInfo, Grade, GradeItem, GradeStudentProfile, GpaSemesterSub, TermGrade } from 'core_model';
import { GradeRepository, GradeRepositoryProvider } from 'data_grade';
import { HdsNavDestination } from '@kit.UIDesignKit';

@Component
export struct GradePage {
  private readonly repository: GradeRepository = GradeRepositoryProvider.get();
  @State grade?: Grade = undefined;
  @State selectedTerm: string = '';
  @State query: string = '';
  @State searchActive: boolean = false;
  @State termSheetVisible: boolean = false;
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State profiles: Array<GradeStudentProfile> = [];
  @State selectedProfileId: string = '';
  @State rank?: GpaRankInfo = undefined;
  @State rankMessage: string = '';

  aboutToAppear(): void {
    this.load(false);
  }

  private async load(refresh: boolean): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    const result = await this.repository.getGrade(refresh);
    if (result.isSuccess && result.data) {
      this.grade = result.data;
      this.profiles = this.repository.getProfiles();
      if (this.profiles.length > 0 && this.selectedProfileId.length === 0) this.selectedProfileId = this.profiles[0].id;
      const profileGrade = this.repository.getGradeForProfile(this.selectedProfileId);
      if (profileGrade) this.grade = profileGrade;
      const terms = result.data.termGradeList ?? [];
      if (this.selectedTerm.length === 0 && terms.length > 0) {
        this.selectedTerm = this.termKey(terms[0]);
      }
    } else {
      this.errorMessage = result.error?.message ?? '成绩加载失败';
    }
    this.isLoading = false;
    if (this.selectedProfileId.length > 0) this.loadRank(refresh);
  }

  private async loadRank(refresh: boolean): Promise<void> {
    this.rankMessage = '';
    const result = await this.repository.getGpaRank(this.selectedProfileId, refresh);
    if (result.isSuccess && result.data) this.rank = result.data;
    else { this.rank = undefined; this.rankMessage = result.error?.message ?? '当前学籍暂无专业排名'; }
  }

  private selectProfile(id: string): void {
    this.selectedProfileId = id; this.rank = undefined; this.rankMessage = '';
    const grade = this.repository.getGradeForProfile(id);
    if (grade) { this.grade = grade; const terms = grade.termGradeList ?? [];
      this.selectedTerm = terms.length > 0 ? this.termKey(terms[0]) : ''; }
    this.loadRank(false);
  }

  private termKey(term: TermGrade): string {
    return `${term.schoolYear ?? ''}-${term.schoolTerm ?? ''}`;
  }

  private termLabel(term: TermGrade | undefined): string {
    return `${term?.schoolYear ?? ''} 第 ${term?.schoolTerm ?? ''} 学期`;
  }

  private termLabels(): Array<string> {
    return (this.grade?.termGradeList ?? []).map((term: TermGrade): string => this.termLabel(term));
  }

  private selected(): TermGrade | undefined {
    return (this.grade?.termGradeList ?? []).find((term: TermGrade): boolean => this.termKey(term) === this.selectedTerm);
  }

  private currentTermRank(): GpaSemesterSub | undefined {
    const semesterId = this.selected()?.termGradeList?.[0]?.semesterId;
    return (this.rank?.gpaSemesterSubs ?? []).find((item: GpaSemesterSub) => item.semesterId === semesterId);
  }

  private profileLabel(profile: GradeStudentProfile): string {
    return [profile.trainingType, profile.department, profile.major].filter((value: string) => value.length > 0).join(' · ');
  }

  private visibleItems(): Array<GradeItem> {
    const normalized = this.query.trim().toLowerCase();
    const all = normalized.length === 0
      ? this.selected()?.termGradeList ?? []
      : (this.grade?.termGradeList ?? []).flatMap((term: TermGrade): Array<GradeItem> => term.termGradeList ?? []);
    if (normalized.length === 0) {
      return all;
    }
    return all.filter((item: GradeItem): boolean =>
      `${item.course ?? ''} ${item.courseNum ?? ''} ${item.courseType ?? ''}`.toLowerCase().includes(normalized));
  }

  @Builder
  private summary() {
    Column({ space: 12 }) {
      AhuInsetCard() { Row() {
        Column({ space: 4 }) {
          Text('本学期 GPA').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
          Text(this.selected()?.termGradePointAverage ?? '--').fontSize(28).fontWeight(FontWeight.Bold);
        }.layoutWeight(1).alignItems(HorizontalAlign.Start);
        Column({ space: 4 }) {
          Text('总 GPA').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
          Text(this.grade?.totalGradePointAverage ?? '--').fontSize(28).fontWeight(FontWeight.Bold);
        }.layoutWeight(1).alignItems(HorizontalAlign.Start);
        Column({ space: 4 }) {
          Text('总学分').fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
          Text(this.grade?.totalCredit ?? '--').fontSize(28).fontWeight(FontWeight.Bold);
        }.layoutWeight(1).alignItems(HorizontalAlign.Start);
      }.width('100%'); }
      AhuInsetCard() {
        Column({ space: 8 }) {
          Row() { Text('总专业排名').layoutWeight(1).fontColor(AhuColors.onSurfaceSecondary);
            Text(this.rank ? `${this.rank.majorRank} / ${this.rank.majorHeadCount}` : '--').fontWeight(FontWeight.Bold); }
          Row() { Text('本学期专业排名').layoutWeight(1).fontColor(AhuColors.onSurfaceSecondary);
            Text(this.currentTermRank() ? `${this.currentTermRank()?.majorRank} / ${this.rank?.majorHeadCount}` : '--').fontWeight(FontWeight.Bold); }
          Row() { Text('排名更新时间').layoutWeight(1).fontColor(AhuColors.onSurfaceSecondary);
            Text(this.rank?.updatedDateTimeStr ?? '--').fontSize(AhuTypography.label); }
          if (this.rankMessage.length > 0) Text(this.rankMessage).fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
        }.width('100%');
      }
    }
  }

  @Builder
  private gradeCard(item: GradeItem) {
    AhuInsetCard({ cornerRadius: 8 }) {
      Column({ space: 7 }) {
        Text(item.course ?? '').fontSize(AhuTypography.body).fontWeight(FontWeight.Bold).fontColor(AhuColors.onSurface);
        Text(`成绩 ${item.grade ?? '--'} · 绩点 ${item.gradePoint ?? '--'} · 学分 ${item.credit ?? '--'}`)
          .fontSize(AhuTypography.body).fontColor(AhuColors.onSurface);
        Text(`${item.courseType ?? ''} (${item.courseNum ?? ''})`)
          .fontSize(AhuTypography.label).fontColor(AhuColors.onSurfaceSecondary);
        if ((item.gradeDetail ?? '').length > 0) {
          Text((item.gradeDetail ?? '').replace(/<[^>]*>/g, '').trim())
            .fontSize(12).fontColor(AhuColors.primaryAction);
        }
      }.width('100%').alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private searchBar() {
    Row({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(16)
          .fontColor([AhuColors.onSurfaceSecondary]);
        TextInput({ text: this.query, placeholder: '搜索课程、课程号或课程性质' })
          .layoutWeight(1)
          .fontColor(AhuColors.onSurface)
          .placeholderColor(AhuColors.onSurfaceSecondary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.query = value; });
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
        .onClick(() => { this.searchActive = false; this.query = ''; });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private termSheet() {
    Column({ space: 4 }) {
      ForEach(this.termLabels(), (label: string, index: number) => {
        Row({ space: 12 }) {
          Text(label)
            .fontSize(16)
            .fontColor(AhuColors.onSurface)
            .layoutWeight(1);
          if (label === this.termLabel(this.selected())) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(18)
              .fontColor([AhuColors.primaryAction]);
          }
        }
        .width('100%')
        .padding({ top: 14, bottom: 14, left: 16, right: 16 })
        .onClick(() => {
          const terms = this.grade?.termGradeList ?? [];
          if (index >= 0 && index < terms.length) {
            this.selectedTerm = this.termKey(terms[index]);
          }
          this.termSheetVisible = false;
        });
      }, (label: string) => label);
    }
    .padding({ top: 8, bottom: 24 });
  }

  build() {
    HdsNavDestination() {
      Column({ space: 16 }) {
        if (this.searchActive) {
          this.searchBar();
        }
        if (this.isLoading) {
          AhuLoading({ message: '正在加载成绩' });
        } else if (this.errorMessage.length > 0) {
          Column({ space: 14 }) {
            Text(this.errorMessage).fontColor(AhuColors.error).textAlign(TextAlign.Center);
            Button('重试').onClick(() => this.load(false));
          }.layoutWeight(1).justifyContent(FlexAlign.Center);
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // FREE 模式标题栏高度 138vp，滚动内容顶部预留占位避免被标题栏覆盖
              Blank().height(138)
              if (this.query.length === 0) {
                if (this.profiles.length > 1) {
                  Scroll() { Row({ space: 8 }) {
                    ForEach(this.profiles, (profile: GradeStudentProfile) => {
                      AhuChip({ text: this.profileLabel(profile), selected: this.selectedProfileId === profile.id,
                        clickAction: () => this.selectProfile(profile.id) });
                    }, (profile: GradeStudentProfile) => profile.id);
                  } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).padding({ left: 16, right: 16 });
                }
                this.summary();
              }
              if (this.visibleItems().length === 0) {
                AhuEmptyState({ text: this.query.length > 0 ? '未找到相关课程' : '本学期暂无成绩' });
              } else {
                ForEach(this.visibleItems(), (item: GradeItem) => { this.gradeCard(item); },
                  (item: GradeItem) => `${item.semesterId}-${item.courseNum}`);
              }
            }.width('100%').padding({ bottom: 24 });
          }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off);
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AhuColors.pageBackground);
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '成绩单',
          subTitle: this.termLabel(this.selected())
        },
        menu: {
          maxCount: 3,
          value: [
            {
              content: {
                icon: $r('sys.symbol.magnifyingglass'),
                action: () => { this.searchActive = true; }
              }
            },
            {
              content: {
                icon: $r('sys.symbol.line_3_horizontal'),
                action: () => { this.termSheetVisible = true; }
              }
            },
            {
              content: {
                icon: $r('sys.symbol.arrow_clockwise'),
                action: () => { this.load(true); }
              }
            }
          ]
        }
      }
    })
    .bindSheet($$this.termSheetVisible, this.termSheet(), {
      title: { title: '选择学期' },
      height: SheetSize.MEDIUM,
      showClose: true,
      dragBar: true
    })
    .onBackPressed((): boolean => {
      if (this.searchActive) {
        this.searchActive = false;
        this.query = '';
        return true;
      }
      return false;
    });
  }
}
