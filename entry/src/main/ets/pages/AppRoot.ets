import { AhuColors } from 'core_designsystem';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppLaunchGate } from 'feature_login';
import { WeeklySchedulePage } from 'feature_schedule';
import { HomePage } from 'feature_home';
import { GradePage } from 'feature_grade';
import { ExamPage } from 'feature_exam';
import { SchoolCalendarPage } from 'feature_calendar';
import { FreeClassroomPage } from 'feature_classroom';
import { BathroomRechargePage, CardRechargePage, ElectricityRechargePage } from 'feature_payment';
import { ScheduleSetupRepository } from 'data_schedule';
import { LostFoundPage } from 'feature_portal';
import { PhoneBookPage, ToolsPage } from 'feature_tools';
import { WeatherPage } from 'feature_weather';
import { RepositoryPage } from 'feature_repository';
import { SettingsPage, PreferencesPage, LicensePage, ContributorsPage } from 'feature_settings';
import { CourseReminderManager } from 'feature_notification';
import { ScheduleWidgetManager } from 'feature_widget';
import { AppUpdateManager } from 'feature_update';
import { GrayReleaseManager } from 'data_crawler';
import { AppMaintenance } from '../app/AppMaintenance';
import { BackPressDispatcher } from 'core_common';
import { AhuCache } from 'core_datastore';

@Component
export struct AppRoot {
  @State selectedIndex: number = 0;
  @State setupComplete: boolean = false;
  @State activePage: string = '';
  @State homeEditEnabled: boolean = false;
  @StorageLink('ahu_launch_route') @Watch('onLaunchRouteChanged') launchRoute: string = '';
  @StorageLink('ahu_logout_revision') @Watch('onLogoutRevision') logoutRevision: number = 0;
  @StorageLink('ahu_mock_revision') @Watch('onMockRevision') mockRevision: number = 0;
  @StorageLink('ahu_gray_revision') @Watch('onGrayRevision') grayRevision: number = 0;
  @StorageLink('ahu_debug_close_revision') @Watch('onDebugClose') debugCloseRevision: number = 0;
  @StorageLink('ahu_session_active') @Watch('onSessionActiveChanged') sessionActive: boolean = false;
  debugEnabled: boolean = false;
  @BuilderParam debugContent: () => void = this.emptyDebugContent;
  private readonly scheduleSetupRepository: ScheduleSetupRepository = new ScheduleSetupRepository();

  @Builder private emptyDebugContent() {}

  private async logout(clearAll: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const widgetIds = AhuCache.getScheduleWidgetIds();
    await AppMaintenance.logout(context, clearAll);
    await CourseReminderManager.cancelCourseReminders();
    await ScheduleWidgetManager.updateAll(widgetIds);
    if (clearAll) {
      AppStorage.setOrCreate('ahu_theme_color', '');
    }
    this.setupComplete = false;
    const revision = AppStorage.get<number>('ahu_logout_revision') ?? 0;
    AppStorage.setOrCreate('ahu_logout_revision', revision + 1);
  }

  aboutToAppear(): void {
    BackPressDispatcher.register('app_root', () => this.handleBackPress());
    this.setupComplete = this.scheduleSetupRepository.hasCompletedSetup();
    this.onLaunchRouteChanged();
    this.loadGrayState();
    this.syncScheduleConfig();
  }

  aboutToDisappear(): void { BackPressDispatcher.unregister('app_root'); }

  private onSessionActiveChanged(): void {
    // 登录/恢复会话完成后再同步学期，等待教务会话建立
    if (this.sessionActive) {
      setTimeout(() => {
        this.syncScheduleConfig();
      }, 1500);
    }
  }

  private handleBackPress(): boolean {
    if (this.activePage.length > 0) { this.activePage = ''; return true; }
    if (this.selectedIndex !== 0) { this.selectedIndex = 0; return true; }
    return false;
  }

  private async loadGrayState(): Promise<void> {
    this.homeEditEnabled = (await GrayReleaseManager.state()).enabled;
  }

  async syncScheduleConfig(): Promise<void> {
    const config = await this.scheduleSetupRepository.syncRemoteConfig();
    if (!config) return;
    const revision = AppStorage.get<number>('ahu_schedule_config_revision') ?? 0;
    AppStorage.setOrCreate('ahu_schedule_config_revision', revision + 1);
  }

  private requestHomeEdit(): void {
    this.selectedIndex = 0;
    const revision = AppStorage.get<number>('ahu_home_edit_request') ?? 0;
    AppStorage.setOrCreate('ahu_home_edit_request', revision + 1);
  }

  private onLaunchRouteChanged(): void {
    if (this.launchRoute !== 'schedule') return;
    this.activePage = '';
    this.selectedIndex = 1;
    this.launchRoute = '';
  }

  private onLogoutRevision(): void { this.setupComplete = false; this.activePage = ''; }
  private onMockRevision(): void { this.setupComplete = this.scheduleSetupRepository.hasCompletedSetup(); }
  private onGrayRevision(): void { this.loadGrayState(); }
  private onDebugClose(): void { if (this.activePage === 'debug') this.activePage = ''; }

  private terminateApplication(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      context.terminateSelf();
    } catch (_) {
    }
  }

  @Builder
  private mainContent() {
    Tabs({ barPosition: BarPosition.End, index: this.selectedIndex }) {
      TabContent() {
        HomePage({
          active: this.selectedIndex === 0,
          homeEditEnabled: this.homeEditEnabled,
          onOpenSchedule: () => {
            this.selectedIndex = 1;
          },
          onOpenWidget: (route: string) => {
            if (route === 'grade' || route === 'exam' || route === 'school_calendar' || route === 'free_classroom' || route === 'bathroom' || route === 'electricity' || route === 'lost_found' || route === 'phone_book' || route === 'weather' || route === 'repository') {
              this.activePage = route;
            }
          },
          onOpenRecharge: () => {
            this.activePage = 'card_recharge';
          }
        });
      }
      .tabBar(new BottomTabBarStyle({
        normal: new SymbolGlyphModifier($r('sys.symbol.house')),
        selected: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
      }, $r('app.string.nav_home')));

      TabContent() {
        WeeklySchedulePage({ active: this.selectedIndex === 1 });
      }
      .tabBar(new BottomTabBarStyle({
        normal: new SymbolGlyphModifier($r('sys.symbol.calendar')),
        selected: new SymbolGlyphModifier($r('sys.symbol.calendar_fill'))
      }, $r('app.string.nav_schedule')));

      TabContent() {
        ToolsPage({ homeEditEnabled: this.homeEditEnabled, onEditHome: () => this.requestHomeEdit(),
          onOpenWidget: (route: string) => { this.activePage = route; } });
      }
      .tabBar(new BottomTabBarStyle({
        normal: new SymbolGlyphModifier($r('sys.symbol.wrench_and_screwdriver')),
        selected: new SymbolGlyphModifier($r('sys.symbol.wrench_and_screwdriver_fill'))
      }, $r('app.string.nav_tools')));

      TabContent() {
        SettingsPage({
          active: this.selectedIndex === 3,
          appVersion: AppUpdateManager.currentVersion(),
          onLogout: () => this.logout(false),
          onClearAllData: () => this.logout(true),
          debugEnabled: this.debugEnabled,
          onOpenPreferences: () => { this.activePage = 'settings_preferences'; },
          onOpenLicense: () => { this.activePage = 'settings_license'; },
          onOpenContributors: () => { this.activePage = 'settings_contributors'; },
          onOpenDebug: () => { this.activePage = 'debug'; }
        });
      }
      .tabBar(new BottomTabBarStyle({
        normal: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
        selected: new SymbolGlyphModifier($r('sys.symbol.gearshape_fill'))
      }, $r('app.string.nav_settings')));
    }
    .width('100%')
    .height('100%')
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .barOverlap(true)
    .barBackgroundColor(AhuColors.card)
    .barBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .animationDuration(220)
    .onChange((index: number) => {
      this.selectedIndex = index;
    })
    .backgroundColor(AhuColors.pageBackground);
  }

  @Builder
  private postLoginContent() {
    if (this.activePage === 'settings_preferences') {
      PreferencesPage({
        onBack: () => { this.activePage = ''; },
        onReminderChange: (enabled: boolean) => {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          return CourseReminderManager.setEnabled(context, enabled);
        }
      });
    } else if (this.activePage === 'settings_license') {
      LicensePage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'settings_contributors') {
      ContributorsPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'grade') {
      GradePage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'exam') {
      ExamPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'school_calendar') {
      SchoolCalendarPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'free_classroom') {
      FreeClassroomPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'card_recharge') {
      CardRechargePage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'bathroom') {
      BathroomRechargePage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'electricity') {
      ElectricityRechargePage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'lost_found') {
      LostFoundPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'phone_book') {
      PhoneBookPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'weather') {
      WeatherPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'repository') {
      RepositoryPage({ onBack: () => { this.activePage = ''; } });
    } else if (this.activePage === 'debug' && this.debugEnabled) {
      this.debugContent();
    } else {
      this.mainContent();
    }
    // 与安卓保持一致：登录后直接进入主页，课程设置仅在设置页面手动进入
  }

  build() {
    Stack() {
      AppLaunchGate({ rejectAction: () => this.terminateApplication() }) {
        this.postLoginContent();
      }
    }
    .width('100%')
    .height('100%');
  }
}
