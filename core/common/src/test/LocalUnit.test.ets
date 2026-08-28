import { describe, it, expect } from '@ohos/hypium';
import { subscribeSession, unsubscribeSession, expireSession, activateSession, getSessionExpired } from '../main/ets/common/AppResult';
import { BackPressDispatcher } from '../main/ets/common/BackPressDispatcher';

export default function localUnitTest() {
  describe('appSessionState', () => {
    it('notifiesEachSubscriberOnce', 0, () => {
      let firstCount = 0;
      let secondCount = 0;
      const first = (): void => { firstCount++; };
      const second = (): void => { secondCount++; };
      subscribeSession(first);
      subscribeSession(first);
      subscribeSession(second);
      expireSession();
      expect(firstCount).assertEqual(1);
      expect(secondCount).assertEqual(1);
      expect(getSessionExpired()).assertTrue();
      unsubscribeSession(first);
      unsubscribeSession(second);
      activateSession();
    });

    it('stopsNotificationsAfterUnsubscribe', 0, () => {
      let count = 0;
      const listener = (): void => { count++; };
      subscribeSession(listener);
      unsubscribeSession(listener);
      expireSession();
      expect(count).assertEqual(0);
      activateSession();
      expect(getSessionExpired()).assertFalse();
    });
  });

  describe('backPressDispatcher', () => {
    it('usesNewestHandlerFirstAndStopsWhenHandled', 0, () => {
      const calls: Array<string> = [];
      BackPressDispatcher.register('test-root', (): boolean => { calls.push('root'); return true; });
      BackPressDispatcher.register('test-dialog', (): boolean => { calls.push('dialog'); return true; });
      expect(BackPressDispatcher.handle()).assertTrue();
      expect(calls.join(',')).assertEqual('dialog');
      BackPressDispatcher.unregister('test-dialog');
      BackPressDispatcher.unregister('test-root');
    });

    it('fallsThroughAndSupportsUnregister', 0, () => {
      const calls: Array<string> = [];
      BackPressDispatcher.register('test-root', (): boolean => { calls.push('root'); return true; });
      BackPressDispatcher.register('test-child', (): boolean => { calls.push('child'); return false; });
      expect(BackPressDispatcher.handle()).assertTrue();
      expect(calls.join(',')).assertEqual('child,root');
      BackPressDispatcher.unregister('test-child');
      BackPressDispatcher.unregister('test-root');
      expect(BackPressDispatcher.handle()).assertFalse();
    });
  });
}
