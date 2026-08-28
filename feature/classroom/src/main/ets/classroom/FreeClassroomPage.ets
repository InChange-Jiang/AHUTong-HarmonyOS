import { AhuColors, AhuInsetCard, AhuLoading, AhuToolbar, AhuTypography } from 'core_designsystem';
import { AcademicCrawlerClient } from 'data_crawler';
import { AhuCache } from 'core_datastore';
import { Building, FreeClassroomFilterDialog } from './FreeClassroomFilterDialog';

interface RoomBuilding { id: number; nameZh: string; }
interface FreeRoom { id: number; nameZh: string; floor: number; remark?: string; building: RoomBuilding; }
interface FreeRoomResponse { roomList?: Array<FreeRoom>; }
interface DateTimeSegmentRequest {
  startDateTime: string; endDateTime: string; startTime: string; endTime: string;
  units: Array<string>; weekdays: Array<string>;
}
interface FreeRoomRequest {
  buildingId: string; campusId: string; dateTimeSegmentCmd: DateTimeSegmentRequest;
  hasDataPermission: boolean; roomId: string; seatsForLessonGte: string;
}

@Component
export struct FreeClassroomPage {
  private readonly client: AcademicCrawlerClient = new AcademicCrawlerClient();
  @State campusId: number = 1;
  @State buildings: Array<Building> = [];
  @State selectedBuildings: Array<number> = [];
  @State selectedUnits: Array<number> = [];
  @State startDate: string = '';
  @State endDate: string = '';
  @State rooms: Array<FreeRoom> = [];
  @State isLoadingBuildings: boolean = true;
  @State isSearching: boolean = false;
  @State errorMessage: string = '';
  onBack: () => void = () => {};

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: FreeClassroomFilterDialog({
      campusId: this.campusId,
      buildings: this.buildings,
      selectedBuildingIds: this.selectedBuildings,
      selectedUnits: this.selectedUnits,
      startDate: this.startDate,
      endDate: this.endDate,
      onApply: (campusId: number, selectedBuildings: Array<number>, selectedUnits: Array<number>, startDate: string, endDate: string) => {
        this.campusId = campusId;
        this.selectedBuildings = selectedBuildings;
        this.selectedUnits = selectedUnits;
        this.startDate = startDate;
        this.endDate = endDate;
        this.search();
      }
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    autoCancel: true,
    offset: { dx: 0, dy: 0 }
  });

  aboutToAppear(): void {
    const today = this.formatDate(new Date());
    this.startDate = today; this.endDate = today; this.loadBuildings();
  }

  private async loadBuildings(): Promise<void> {
    this.isLoadingBuildings = true; this.errorMessage = ''; this.selectedBuildings = []; this.rooms = [];
    if (AhuCache.getMockData()) {
      const scenario = AhuCache.getMockScenario();
      if (scenario === 'network_error' || scenario === 'expired_login') {
        this.buildings = []; this.errorMessage = scenario === 'expired_login' ? 'Mock 场景：登录状态已过期' : 'Mock 场景：接口返回 500';
      } else if (scenario === 'empty_campus' || (scenario === 'longhe_only' && this.campusId !== 2)) {
        this.buildings = [];
      } else {
        const prefix = this.campusId === 2 ? '龙河' : '磬苑';
        this.buildings = [{ id: this.campusId * 100 + 1, nameZh: `${prefix}教学主楼` },
          { id: this.campusId * 100 + 2, nameZh: `${prefix}公共教学楼` }];
      }
      this.isLoadingBuildings = false; return;
    }
    const result = await this.client.getJson<Array<Building>>(
      `https://jw.ahu.edu.cn/student/ws/room/get-buildings?campusId=${this.campusId}&hasDataPermission=false`);
    if (result.isSuccess) this.buildings = (result.data ?? []).sort((a: Building, b: Building): number => a.nameZh.localeCompare(b.nameZh));
    else { this.buildings = []; this.errorMessage = result.error?.message ?? '教学楼加载失败'; }
    this.isLoadingBuildings = false;
  }

  private formatDate(date: Date): string {
    return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`;
  }

  private hasFilter(): boolean {
    const today = this.formatDate(new Date());
    return this.campusId !== 1
      || this.selectedBuildings.length > 0
      || this.selectedUnits.length > 0
      || this.startDate !== today
      || this.endDate !== today;
  }

  private async search(): Promise<void> {
    const ids = this.selectedBuildings.length > 0 ? this.selectedBuildings : this.buildings.map((item: Building): number => item.id);
    if (ids.length === 0) { this.errorMessage = '当前校区暂无教学楼数据'; return; }
    const units = (this.selectedUnits.length > 0 ? this.selectedUnits : Array.from({ length: 13 }, (_: Object, i: number) => i + 1))
      .map((unit: number): string => `${unit}`);
    this.isSearching = true; this.errorMessage = ''; const rooms: Array<FreeRoom> = [];
    if (AhuCache.getMockData()) {
      const scenario = AhuCache.getMockScenario();
      if (scenario === 'network_error' || scenario === 'expired_login') {
        this.rooms = []; this.errorMessage = scenario === 'expired_login' ? 'Mock 场景：登录状态已过期' : 'Mock 场景：接口返回 500';
      } else {
        ids.forEach((buildingId: number) => {
          const building = this.buildings.find((item: Building) => item.id === buildingId);
          if (!building) return;
          rooms.push({ id: buildingId * 10 + 1, nameZh: '301', floor: 3, building: { id: building.id, nameZh: building.nameZh }, remark: '多媒体教室' });
          rooms.push({ id: buildingId * 10 + 2, nameZh: '302', floor: 3, building: { id: building.id, nameZh: building.nameZh } });
        });
        this.rooms = rooms;
      }
      this.isSearching = false; return;
    }
    for (let index = 0; index < ids.length; index++) {
      const request: FreeRoomRequest = { buildingId: `${ids[index]}`, campusId: `${this.campusId}`,
        dateTimeSegmentCmd: { startDateTime: this.startDate, endDateTime: this.endDate, startTime: '', endTime: '', units: units, weekdays: [] },
        hasDataPermission: false, roomId: '', seatsForLessonGte: '' };
      const body = JSON.stringify(request);
      const result = await this.client.postJson<FreeRoomResponse>('https://jw.ahu.edu.cn/student/ws/room-borrow/free-list', body);
      if (result.isSuccess) rooms.push(...(result.data?.roomList ?? []));
      else this.errorMessage = result.error?.message ?? '空闲教室查询失败';
    }
    const unique = new Map<string, FreeRoom>();
    rooms.forEach((room: FreeRoom) => unique.set(`${room.building.id}-${room.id}`, room));
    this.rooms = Array.from(unique.values()).sort((a: FreeRoom, b: FreeRoom): number =>
      a.building.nameZh.localeCompare(b.building.nameZh) || a.floor - b.floor || a.nameZh.localeCompare(b.nameZh));
    this.isSearching = false;
  }

  build() {
    Column({ space: 16 }) {
      AhuToolbar({
        title: '空闲教室',
        filterable: true,
        filterActive: this.hasFilter(),
        onFilterClick: (): void => this.filterDialogController.open()
      }) {
      }
      if (this.isSearching) {
        Column() {
          AhuLoading({ message: '正在查询空闲教室' });
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else if (this.rooms.length > 0) {
        Scroll() {
          Column({ space: 14 }) {
            AhuInsetCard() {
              Column({ space: 10 }) {
                Row() {
                  Text('查询结果').fontWeight(FontWeight.Bold).layoutWeight(1);
                  Text(`${this.rooms.length} 间`).fontColor(AhuColors.onSurfaceSecondary);
                }
                ForEach(this.rooms, (room: FreeRoom) => {
                  Column({ space: 4 }) {
                    Text(room.nameZh).fontWeight(FontWeight.Bold);
                    Text(`${room.building.nameZh} · ${room.floor} 层${room.remark ? ` · ${room.remark}` : ''}`).fontColor(AhuColors.onSurfaceSecondary);
                  }
                  .width('100%')
                  .padding(14)
                  .alignItems(HorizontalAlign.Start)
                  .backgroundColor(AhuColors.cardStrong)
                  .borderRadius(20);
                }, (room: FreeRoom) => `${room.building.id}-${room.id}`);
              }
              .width('100%');
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 });
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top);
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.line_3_horizontal')).fontSize(40).fontColor([AhuColors.onSurfaceSecondary]);
          Text(this.errorMessage.length > 0 ? this.errorMessage : '点击右上角筛选空闲教室')
            .fontSize(AhuTypography.label)
            .fontColor(this.errorMessage.length > 0 ? AhuColors.error : AhuColors.onSurfaceSecondary);
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AhuColors.pageBackground);
  }
}
