import { AhuColors, AhuLoading } from 'core_designsystem';
import { getAuthRepository, AuthSession } from 'data_auth';
import { LaunchConsentGate } from './LaunchConsentGate';
import { LoginPage } from './LoginPage';
import { AhuCache } from 'core_datastore';

@Component
export struct AppLaunchGate {
  @State restoring: boolean = true;
  @StorageLink('ahu_logout_revision') logoutRevision: number = 0;
  @StorageLink('ahu_session_active') sessionActive: boolean = false;
  rejectAction: () => void = () => {};

  @Builder
  private emptyContent() {}

  @BuilderParam content: () => void = this.emptyContent;

  async aboutToAppear(): Promise<void> {
    if (!AuthSession.isLoggedIn()) {
      this.restoring = false;
      return;
    }
    if (AhuCache.getMockData()) {
      this.restoring = false;
      return;
    }
    const result = await getAuthRepository().restoreSession();
    this.restoring = false;
  }

  aboutToDisappear(): void {
  }

  @Builder
  private loginContent() {
    LoginPage({
      onLoggedIn: () => {
        AppStorage.set<boolean>('ahu_session_active', true);
      }
    });
  }

  build() {
    if (this.restoring) {
      Stack() {
        Column() {
          AhuLoading({ message: $r('app.string.login_restoring_session') });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AhuColors.pageBackground);
      }
      .width('100%')
      .height('100%');
    } else if (this.logoutRevision >= 0 && this.sessionActive) {
      Stack() {
        this.content();
      }
      .width('100%')
      .height('100%');
    } else {
      Stack() {
        LaunchConsentGate({
          rejectAction: this.rejectAction,
          content: this.loginContent
        });
      }
      .width('100%')
      .height('100%');
    }
  }
}
