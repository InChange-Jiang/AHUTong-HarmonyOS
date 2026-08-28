import { http } from '@kit.NetworkKit';

const COOKIE_ATTRIBUTES: Array<string> = [
  'path', 'domain', 'expires', 'max-age', 'secure', 'httponly', 'samesite', 'priority'
];

interface CookieInfo {
  name: string;
  value: string;
}

export class MemoryCookieJar {
  private values: Map<string, string> = new Map<string, string>();

  save(responseCookies: string): void;
  save(responseCookies: CookieInfo[] | Array<string>): void;
  save(responseCookies: string | CookieInfo[] | Array<string>): void {
    if (Array.isArray(responseCookies)) {
      // 原生 Cookie[] 数组；手动解析的 Set-Cookie 头是 string[]
      for (const cookie of responseCookies) {
        if (typeof cookie === 'string') {
          this.saveRaw(cookie);
        } else {
          this.savePair(cookie.name, cookie.value);
        }
      }
      return;
    }
    this.saveRaw(responseCookies);
  }

  private saveRaw(raw: string): void {
    if (raw.length === 0) {
      return;
    }
    // Netscape cookie 文件格式：每行一个 cookie，制表符分隔
    // domain flag path secure expiry name value
    if (raw.includes('\t')) {
      const lines = raw.split(/\r?\n/);
      for (const line of lines) {
        const fields = line.split('\t');
        if (fields.length >= 7 && fields[5].trim().length > 0) {
          this.savePair(fields[5].trim(), fields[6].trim());
        }
      }
      return;
    }
    // 普通 Set-Cookie 字符串：name=value; Path=/; HttpOnly; ...
    const segments = raw.split(/[;,]/);
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index].trim();
      const equals = segment.indexOf('=');
      if (equals <= 0) {
        continue;
      }
      this.savePair(segment.substring(0, equals).trim(), segment.substring(equals + 1).trim());
    }
  }

  private savePair(name: string, value: string): void {
    if (COOKIE_ATTRIBUTES.includes(name.toLowerCase())) {
      return;
    }
    if (value.length === 0) {
      this.values.delete(name);
    } else {
      this.values.set(name, value);
    }
  }

  header(): string {
    const pairs: Array<string> = [];
    this.values.forEach((value: string, name: string) => {
      pairs.push(`${name}=${value}`);
    });
    return pairs.join('; ');
  }

  count(): number {
    return this.values.size;
  }

  clear(): void {
    this.values.clear();
  }
}

export const portalCookies: MemoryCookieJar = new MemoryCookieJar();
export const academicCookies: MemoryCookieJar = new MemoryCookieJar();

let academicReloginHandler: AcademicReloginHandler | undefined;
let portalReloginHandler: AcademicReloginHandler | undefined;

export function setAcademicReloginHandler(handler: AcademicReloginHandler): void {
  academicReloginHandler = handler;
}

export async function reauthenticateAcademic(): Promise<boolean> {
  if (!academicReloginHandler) {
    return false;
  }
  return academicReloginHandler.relogin();
}

export function setPortalReloginHandler(handler: AcademicReloginHandler): void {
  portalReloginHandler = handler;
}

export async function reauthenticatePortal(): Promise<boolean> {
  return portalReloginHandler?.relogin() ?? false;
}

export function clearAllCookies(): void {
  portalCookies.clear();
  academicCookies.clear();
}

export interface AcademicReloginHandler {
  relogin(): Promise<boolean>;
}

/**
 * 从 http 响应中提取 Cookie 存入 jar。
 * 鸿蒙会把重定向链中所有 Set-Cookie 合并为 header 的 set-cookie 数组；
 * response.cookies 可能为空或返回 Netscape 制表符格式，均作为补充来源。
 */
export function saveResponseCookies(response: http.HttpResponse, jar: MemoryCookieJar): void {
  const headers = response.header as Record<string, Object>;
  const setCookie = headers['set-cookie'] as Array<string> | undefined;
  if (setCookie !== undefined && setCookie.length > 0) {
    jar.save(setCookie);
  }
  if (response.cookies.length > 0) {
    jar.save(response.cookies);
  }
}