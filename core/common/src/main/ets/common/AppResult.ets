export enum AppErrorKind {
  TRANSPORT = 'transport',
  TIMEOUT = 'timeout',
  HTTP = 'http',
  AUTHENTICATION = 'authentication',
  PARSE = 'parse',
  UNKNOWN = 'unknown'
}

export interface AppError {
  kind: AppErrorKind;
  message: string;
  code?: number;
}

export interface AppResult<T> {
  isSuccess: boolean;
  data?: T;
  error?: AppError;
}

export function success<T>(data: T): AppResult<T> {
  return { isSuccess: true, data: data };
}

export function failure<T>(kind: AppErrorKind, message: string, code?: number): AppResult<T> {
  return {
    isSuccess: false,
    error: { kind: kind, message: message, code: code }
  };
}

let sessionListeners: Array<() => void> = [];
let sessionExpired: boolean = false;

export function getSessionExpired(): boolean {
  return sessionExpired;
}

export function activateSession(): void {
  sessionExpired = false;
  AppStorage.set<boolean>('ahu_session_active', true);
}

export function expireSession(): void {
  sessionExpired = true;
  sessionListeners.slice().forEach((listener: () => void): void => listener());
}

export function subscribeSession(listener: () => void): void {
  if (!sessionListeners.includes(listener)) sessionListeners.push(listener);
}

export function unsubscribeSession(listener: () => void): void {
  sessionListeners = sessionListeners.filter((item: () => void): boolean => item !== listener);
}
