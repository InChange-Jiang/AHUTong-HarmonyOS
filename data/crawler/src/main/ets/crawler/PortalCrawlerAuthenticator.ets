import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { AppErrorKind, AppResult, success, failure } from 'core_common';
import { User } from 'core_model';
import { CasAuthenticator } from './CasAuthenticator';
import { portalCookies, saveResponseCookies } from './CrawlerSession';

interface OcrResponse {
  result: string;
  error?: string;
}

interface PortalUser {
  userName: string;
  idNumber: string;
}

interface PortalLoginObject {
  user: PortalUser;
}

interface PortalLoginResponse {
  code: number;
  msg: string;
  object?: PortalLoginObject;
}

export interface CrawlerAuthenticator {
  login(username: string, password: string): Promise<AppResult<User>>;
  clearSession(): void;
}

const CAPTCHA_URL: string = 'https://adwmh.ahu.edu.cn/remind/authcode';
const OCR_URL: string = 'https://openahu.org/ocr/captcha';
const LOGIN_URL: string = 'https://adwmh.ahu.edu.cn/user/login';

/**
 * 使用单个 http.createHttp() 实例处理所有 adwmh 请求，
 * 手动维护 JSESSIONID 确保验证码会话一致。
 */
export class PortalCrawlerAuthenticator implements CrawlerAuthenticator {
  private readonly casAuthenticator: CasAuthenticator = new CasAuthenticator();
  private portalHttp: http.HttpRequest | undefined;
  private jsessionId: string = '';

  private getPortalHttp(): http.HttpRequest {
    if (!this.portalHttp) {
      this.portalHttp = http.createHttp();
    }
    return this.portalHttp;
  }

  private destroyPortalHttp(): void {
    if (this.portalHttp) {
      this.portalHttp.destroy();
      this.portalHttp = undefined;
    }
    this.jsessionId = '';
    // 同步清空全局 portalCookies
    portalCookies.clear();
  }

  private headers(contentType?: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': '*/*',
      'X-Requested-With': 'XMLHttpRequest'
    };
    if (contentType) {
      headers['Content-Type'] = contentType;
    }
    if (this.jsessionId.length > 0) {
      headers['Cookie'] = 'JSESSIONID=' + this.jsessionId;
    }
    return headers;
  }

  private parseCookies(response: http.HttpResponse): void {
    // 从 header set-cookie 数组 / response.cookies（Netscape 制表符格式）解析
    saveResponseCookies(response, portalCookies);
    const cookiesStr: string = response.cookies;
    if (!cookiesStr || cookiesStr.length === 0) {
      return;
    }
    // 鸿蒙 http 模块返回的 cookies 是 Netscape cookie 文件格式：
    // #HttpOnly_adwmh.ahu.edu.cn FALSE   /       FALSE   0       JSESSIONID      46892064222F3F4300945EAB0DA1129B
    // 字段用制表符分隔，JSESSIONID 后面是制表符而非等号
    const match = cookiesStr.match(/JSESSIONID\s+(\S+)/i);
    if (match) {
      this.jsessionId = match[1];
      // 同步保存到全局 portalCookies 供 PortalCrawlerClient 使用
      portalCookies.save(`JSESSIONID=${this.jsessionId}`);
    }
  }

  private async fetchCaptcha(): Promise<AppResult<ArrayBuffer>> {
    const request = this.getPortalHttp();
    try {
      const response = await request.request(CAPTCHA_URL, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': '*/*',
          'X-Requested-With': 'XMLHttpRequest'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
        return failure<ArrayBuffer>(AppErrorKind.HTTP, `验证码获取失败（${response.responseCode}）`);
      }
      this.parseCookies(response);
      return success<ArrayBuffer>(response.result);
    } catch (error) {
      const businessError = error as BusinessError;
      return failure<ArrayBuffer>(AppErrorKind.TRANSPORT, businessError.message ?? '验证码获取失败');
    }
  }

  private async recognizeCaptcha(image: ArrayBuffer): Promise<AppResult<string>> {
    const request = http.createHttp();
    try {
      const boundary = '----AHUTongCaptchaBoundary' + Date.now().toString();
      const textEncoder = new util.TextEncoder();

      let bodyParts: Uint8Array[] = [];
      bodyParts.push(textEncoder.encode(`--${boundary}\r\n`));
      bodyParts.push(textEncoder.encode(
        'Content-Disposition: form-data; name="captcha"; filename="img.jpg"\r\n'));
      bodyParts.push(textEncoder.encode('Content-Type: image/jpg\r\n'));
      bodyParts.push(textEncoder.encode('\r\n'));
      bodyParts.push(new Uint8Array(image));
      bodyParts.push(textEncoder.encode(`\r\n--${boundary}--\r\n`));

      const totalLength = bodyParts.reduce((sum, part) => sum + part.length, 0);
      const finalBody = new Uint8Array(totalLength);
      let offset = 0;
      for (const part of bodyParts) {
        finalBody.set(part, offset);
        offset += part.length;
      }

      const response = await request.request(OCR_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': '*/*',
          'User-Agent': 'AHUTong/1.0.0 (Android)',
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': `multipart/form-data; boundary=${boundary}`
        },
        extraData: finalBody.buffer as ArrayBuffer,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20_000,
        readTimeout: 30_000,
        usingCache: false
      });
      if (response.responseCode !== 200) {
        const errorBody = response.result as string;
        return failure<string>(AppErrorKind.HTTP, `验证码识别失败（${response.responseCode}）: ${errorBody ?? ''}`);
      }
      const rawBody = response.result as string;
      const parsed = JSON.parse(rawBody) as OcrResponse;
      if (!parsed.result || parsed.result.trim().length === 0) {
        const errorMsg = parsed.error ?? 'no result';
        return failure<string>(AppErrorKind.PARSE, `验证码识别失败（空结果）: ${errorMsg}, raw=${rawBody}`);
      }
      return success<string>(parsed.result.trim());
    } catch (error) {
      const businessError = error as BusinessError;
      return failure<string>(AppErrorKind.TRANSPORT, businessError.message ?? '验证码识别失败');
    } finally {
      request.destroy();
    }
  }

  private async portalLogin(username: string, password: string, captcha: string): Promise<AppResult<User>> {
    const request = this.getPortalHttp();
    const body = `username=${encodeURIComponent(username)}` +
      `&pwd=${encodeURIComponent(password)}` +
      `&flag=0&imgcode=${encodeURIComponent(captcha)}`;
    try {
      const response = await request.request(LOGIN_URL, {
        method: http.RequestMethod.POST,
        header: this.headers('application/x-www-form-urlencoded; charset=UTF-8'),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15_000,
        readTimeout: 30_000,
        usingCache: false
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return failure<User>(AppErrorKind.HTTP, `登录请求失败（${response.responseCode}）`);
      }
      const raw: string = response.result as string;
      const parsed = JSON.parse(raw) as PortalLoginResponse;
      if (parsed.code !== 10000 || !parsed.object) {
        return failure<User>(AppErrorKind.AUTHENTICATION, parsed.msg || '账号、密码或验证码错误');
      }
      return success<User>({
        name: parsed.object.user.userName,
        xh: parsed.object.user.idNumber
      });
    } catch (error) {
      const businessError = error as BusinessError;
      return failure<User>(AppErrorKind.TRANSPORT, businessError.message ?? '登录请求失败');
    }
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  private async portalLoginWithRetry(username: string, password: string): Promise<AppResult<User>> {
    let lastError: AppResult<User> = failure<User>(AppErrorKind.AUTHENTICATION, '登录失败');
    for (let attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await this.delay(1500);
      }
      const image = await this.fetchCaptcha();
      if (!image.isSuccess || !image.data) {
        lastError = failure<User>(image.error?.kind ?? AppErrorKind.UNKNOWN,
          image.error?.message ?? '验证码获取失败', image.error?.code);
        continue;
      }
      const captcha = await this.recognizeCaptcha(image.data);
      if (!captcha.isSuccess || !captcha.data) {
        lastError = failure<User>(captcha.error?.kind ?? AppErrorKind.UNKNOWN,
          captcha.error?.message ?? '验证码识别失败', captcha.error?.code);
        continue;
      }
      const result = await this.portalLogin(username, password, captcha.data);
      if (result.isSuccess) {
        return result;
      }
      lastError = result;
    }
    return lastError;
  }

  async login(username: string, password: string): Promise<AppResult<User>> {
    try {
      this.destroyPortalHttp();

      const portalPromise: Promise<AppResult<User>> = this.portalLoginWithRetry(username, password);
      const casPromise: Promise<AppResult<string>> = this.casAuthenticator.login(username, password);
      const portalResult: AppResult<User> = await portalPromise;
      const casResult: AppResult<string> = await casPromise;

      if (portalResult.isSuccess && portalResult.data && casResult.isSuccess) {
        return portalResult;
      }

      const errorMsg = !portalResult.isSuccess
        ? (portalResult.error?.message ?? '门户登录失败')
        : (casResult.error?.message ?? '智慧安大认证失败');
      return failure<User>(AppErrorKind.AUTHENTICATION, errorMsg);
    } catch (e) {
      const businessError = e as BusinessError;
      return failure<User>(AppErrorKind.UNKNOWN, `登录异常: ${businessError.message ?? ''}`);
    }
  }

  clearSession(): void {
    this.destroyPortalHttp();
  }
}
