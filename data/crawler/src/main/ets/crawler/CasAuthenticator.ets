import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppErrorKind, AppResult, success, failure } from 'core_common';
import { academicCookies, saveResponseCookies } from './CrawlerSession';
import { encrypt } from './LegacyCasCipher';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOGIN_PAGE_URL: string = 'https://jw.ahu.edu.cn/student/sso/login';
const DEVICE_URL: string = 'https://one.ahu.edu.cn/cas/device';
const LOGIN_URL: string = 'https://one.ahu.edu.cn/cas/login' +
  '?service=https%3A%2F%2Fjw.ahu.edu.cn%2Fstudent%2Fsso%2Flogin';
const HOME_URL: string = 'https://jw.ahu.edu.cn/student/home';

export class CasAuthenticator {

  extractUserName(html: string): string | undefined {
    const patterns = [
      /<span[^>]*class="[^"]*user-name[^"]*"[^>]*>([^<]+)<\/span>/i,
      /<div[^>]*class="[^"]*user[^"]*"[^>]*>.*<span[^>]*>([^<]+)<\/span>/i,
      /欢迎你[：:]?\s*([^<\s]+)/i,
      /(<span[^>]*>)?([^<]+)(<\/span>)?\s*\(.*?\)/,
      /([^()]+)\s*\([^)]+\)$/
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1] && match[1].trim().length > 0) {
        const name = match[1].trim();
        if (!/^(\d+|ID|学号|username)$/i.test(name)) {
          return name;
        }
      }
    }

    return undefined;
  }


  private headers(contentType?: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': '*/*',
      'User-Agent': 'AHUTong/1.0 (HarmonyOS)'
    };
    const cookie = academicCookies.header();
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    if (contentType) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }

  private logCookies(step: string, setCookie?: Array<string>): void {
    const names: Array<string> = [];
    const pairs = academicCookies.header().split(';');
    for (const pair of pairs) {
      const eq = pair.indexOf('=');
      if (eq > 0) {
        names.push(pair.substring(0, eq).trim());
      }
    }
    hilog.info(0x0000, 'AHUTong', 'cas[%{public}s] setCookie=%{public}d cookies=%{public}d names=%{public}s',
      step, setCookie?.length ?? 0, academicCookies.count(), names.join(','));
  }

  private responseSetCookie(response: http.HttpResponse): Array<string> {
    const headers = response.header as Record<string, Object>;
    const setCookie = headers['set-cookie'] as Array<string> | undefined;
    return setCookie ?? [];
  }

  private extractLoginToken(html: string): string | undefined {
    const nameFirst = html.match(/name=["']lt["'][^>]*value=["']([^"']+)["']/i);
    if (nameFirst && nameFirst.length > 1) {
      return nameFirst[1];
    }
    const valueFirst = html.match(/value=["']([^"']+)["'][^>]*name=["']lt["']/i);
    return valueFirst && valueFirst.length > 1 ? valueFirst[1] : undefined;
  }

  async login(username: string, password: string): Promise<AppResult<string>> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const loginPage: http.HttpResponse = await request.request(LOGIN_PAGE_URL, {
        method: http.RequestMethod.GET,
        header: this.headers(),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false,
        maxRedirects: 10
      });
      saveResponseCookies(loginPage, academicCookies);
      this.logCookies('loginPage', this.responseSetCookie(loginPage));
      if (loginPage.responseCode < 200 || loginPage.responseCode >= 300) {
        return failure<string>(AppErrorKind.HTTP, `教务登录页加载失败（${loginPage.responseCode}）`);
      }
      const loginPageBody = loginPage.result as string;
      if (!loginPageBody) {
        return failure<string>(AppErrorKind.PARSE, '教务登录页返回为空');
      }
      const token = this.extractLoginToken(loginPageBody);
      hilog.info(0x0000, 'AHUTong', 'cas loginPage code=%{public}d len=%{public}d hasToken=%{public}s isLocal=%{public}s',
        loginPage.responseCode, loginPageBody.length, token !== undefined, loginPageBody.includes('authc-local'));
      if (!token) {
        return success<string>(username);
      }

      const cipher = encrypt(username + password + token);
      const deviceBody = `ul=${username.length}&pl=${password.length}` +
        `&rsa=${encodeURIComponent(cipher)}&method=login`;
      const device: http.HttpResponse = await request.request(DEVICE_URL, {
        method: http.RequestMethod.POST,
        header: this.headers('application/x-www-form-urlencoded; charset=UTF-8'),
        extraData: deviceBody,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false
      });
      saveResponseCookies(device, academicCookies);
      this.logCookies('device', this.responseSetCookie(device));
      if (device.responseCode < 200 || device.responseCode >= 300) {
        return failure<string>(AppErrorKind.HTTP, `统一认证设备校验失败（${device.responseCode}）`);
      }

      const loginBody = `rsa=${encodeURIComponent(cipher)}` +
        `&ul=${username.length}&pl=${password.length}` +
        `&lt=${encodeURIComponent(token)}&execution=e1s1&_eventId=submit`;
      const login: http.HttpResponse = await request.request(LOGIN_URL, {
        method: http.RequestMethod.POST,
        header: this.headers('application/x-www-form-urlencoded; charset=UTF-8'),
        extraData: loginBody,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false,
        maxRedirects: 10
      });
      saveResponseCookies(login, academicCookies);
      this.logCookies('login', this.responseSetCookie(login));
      if (login.responseCode < 200 || login.responseCode >= 300) {
        return failure<string>(AppErrorKind.AUTHENTICATION, '智慧安大认证失败');
      }

      const home: http.HttpResponse = await request.request(HOME_URL, {
        method: http.RequestMethod.GET,
        header: this.headers(),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false,
        maxRedirects: 10
      });
      saveResponseCookies(home, academicCookies);
      this.logCookies('home', this.responseSetCookie(home));
      if (home.responseCode < 200 || home.responseCode >= 300) {
        return failure<string>(AppErrorKind.AUTHENTICATION, '智慧安大账号或密码错误');
      }
      const body = home.result as string;
      if (!body || this.extractLoginToken(body)) {
        return failure<string>(AppErrorKind.AUTHENTICATION, '智慧安大账号或密码错误');
      }
      const studentName = this.extractUserName(body) ?? username;
      return success<string>(studentName);
    } catch (error) {
      const businessError = error as BusinessError;
      return failure<string>(AppErrorKind.TRANSPORT, businessError?.message ?? '智慧安大认证失败');
    } finally {
      request.destroy();
    }
  }
}
