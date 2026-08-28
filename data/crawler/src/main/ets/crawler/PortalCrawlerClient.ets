import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppErrorKind, AppResult, success, failure, activateSession, expireSession } from 'core_common';
import { portalCookies, reauthenticatePortal, saveResponseCookies } from './CrawlerSession';

export class PortalCrawlerClient {
  private async requestOnce(url: string, method: http.RequestMethod = http.RequestMethod.GET,
    body?: string, contentType?: string): Promise<AppResult<string>> {
    const request = http.createHttp();
    try {
      const headers: Record<string, string> = { 'Accept': 'application/json', 'User-Agent': 'AHUTong/1.0 (HarmonyOS)', 'X-Requested-With': 'XMLHttpRequest' };
      const cookie = portalCookies.header();
      if (cookie.length > 0) headers['Cookie'] = cookie;
      if (contentType) headers['Content-Type'] = contentType;
      const response = await request.request(url, { method: method, header: headers, extraData: body,
        expectDataType: http.HttpDataType.STRING, connectTimeout: 15_000, readTimeout: 30_000, usingCache: false, maxRedirects: 10 });
      saveResponseCookies(response, portalCookies);
      const status = response.responseCode as number;
      const responseBody = response.result as string;
      if (status === 401 || status === 403 || /\/user\/login|name=["']imgcode["']/i.test(responseBody))
        return failure<string>(AppErrorKind.AUTHENTICATION, '门户登录状态已失效', status);
      if (status < 200 || status >= 300) return failure<string>(AppErrorKind.HTTP, `门户请求失败（${status}）`, status);
      return success<string>(responseBody);
    } catch (error) {
      const businessError = error as BusinessError;
      return failure<string>(AppErrorKind.TRANSPORT, businessError.message ?? '门户网络请求失败', businessError.code);
    } finally { request.destroy(); }
  }

  async getJson<T>(url: string): Promise<AppResult<T>> {
    let result = await this.requestOnce(url);
    if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) {
      if (await reauthenticatePortal()) result = await this.requestOnce(url);
      if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) expireSession();
      else if (result.isSuccess) activateSession();
    }
    if (!result.isSuccess || result.data === undefined)
      return failure<T>(result.error?.kind ?? AppErrorKind.UNKNOWN, result.error?.message ?? '门户请求失败', result.error?.code);
    try { return success<T>(JSON.parse(result.data) as T); }
    catch (_) { return failure<T>(AppErrorKind.PARSE, '门户数据解析失败'); }
  }

  async postJson<T>(url: string, body: string): Promise<AppResult<T>> {
    let result = await this.requestOnce(url, http.RequestMethod.POST, body, 'application/json; charset=UTF-8');
    if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) {
      if (await reauthenticatePortal())
        result = await this.requestOnce(url, http.RequestMethod.POST, body, 'application/json; charset=UTF-8');
      if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) expireSession();
      else if (result.isSuccess) activateSession();
    }
    if (!result.isSuccess || result.data === undefined)
      return failure<T>(result.error?.kind ?? AppErrorKind.UNKNOWN, result.error?.message ?? '门户请求失败', result.error?.code);
    try { return success<T>(JSON.parse(result.data) as T); }
    catch (_) { return failure<T>(AppErrorKind.PARSE, '门户数据解析失败'); }
  }

  async postForm<T>(url: string, body: string): Promise<AppResult<T>> {
    let result = await this.requestOnce(url, http.RequestMethod.POST, body,
      'application/x-www-form-urlencoded; charset=UTF-8');
    if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) {
      if (await reauthenticatePortal())
        result = await this.requestOnce(url, http.RequestMethod.POST, body,
          'application/x-www-form-urlencoded; charset=UTF-8');
      if (!result.isSuccess && result.error?.kind === AppErrorKind.AUTHENTICATION) expireSession();
      else if (result.isSuccess) activateSession();
    }
    if (!result.isSuccess || result.data === undefined)
      return failure<T>(result.error?.kind ?? AppErrorKind.UNKNOWN, result.error?.message ?? '门户请求失败', result.error?.code);
    try { return success<T>(JSON.parse(result.data) as T); }
    catch (_) { return failure<T>(AppErrorKind.PARSE, '门户数据解析失败'); }
  }
}
