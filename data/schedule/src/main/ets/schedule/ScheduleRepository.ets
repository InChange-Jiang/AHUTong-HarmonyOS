import { AppErrorKind, AppResult, success, failure } from 'core_common';
import { AhuCache } from 'core_datastore';
import { Course } from 'core_model';
import { AcademicCrawlerClient } from 'data_crawler';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScheduleReminderCoordinatorProvider } from './ScheduleReminderCoordinator';
import { ScheduleWidgetCoordinatorProvider } from './ScheduleWidgetCoordinator';

interface CurrentSemester {
  id: number;
  name: string;
  schoolYear?: string;
}

interface CourseActivity {
  courseName?: string;
  lessonId?: number;
  room?: string;
  teacherNames?: Array<string>;
  weekIndexes?: Array<number>;
  weekday?: number;
  startUnit?: number;
  endUnit?: number;
}

interface StudentTable {
  activities?: Array<CourseActivity>;
}

interface CourseTableResponse {
  studentTableVms?: Array<StudentTable>;
}

export interface ScheduleRepository {
  getSchedule(refresh?: boolean): Promise<AppResult<Array<Course>>>;
  getNextSchedule(refresh?: boolean): Promise<AppResult<Array<Course>>>;
}

export class CrawlerScheduleSource {
  private static readonly BASE_URL: string = 'https://jw.ahu.edu.cn';
  private readonly client: AcademicCrawlerClient;

  constructor(client: AcademicCrawlerClient = new AcademicCrawlerClient()) {
    this.client = client;
  }

  /**
   * 在字符串中查找平衡的 JSON 对象（正确处理嵌套 {} 和引号内的内容）
   */
  private extractBalancedJson(source: string, startIndex: number): string | undefined {
    if (startIndex >= source.length || source[startIndex] !== '{') {
      return undefined;
    }
    let depth = 0;
    let quote: string | undefined;
    let escaped = false;
    for (let i = startIndex; i < source.length; i++) {
      const ch = source[i];
      if (quote !== undefined) {
        if (escaped) {
          escaped = false;
        } else if (ch === '\\') {
          escaped = true;
        } else if (ch === quote) {
          quote = undefined;
        }
        continue;
      }
      if (ch === '\'' || ch === '"') {
        quote = ch;
      } else if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0) {
          return source.substring(startIndex, i + 1);
        }
        if (depth < 0) {
          return undefined;
        }
      }
    }
    return undefined;
  }

  /**
   * 从 HTML 中提取 currentSemester 的 JSON 字符串。
   * 参照安卓原版逻辑：
   * 1. 先提取 <script> 标签内容
   * 2. 在每个 script 中查找 currentSemester 赋值
   * 3. 使用平衡括号匹配提取完整 JSON 对象（处理嵌套 {}）
   * 4. 也支持 JSON.parse('...') 格式
   */
  private extractCurrentSemesterJson(html: string): string | undefined {
    // 提取所有 <script> 标签内容
    const scriptRegex = /<script[^>]*>([\s\S]*?)<\/script>/gi;
    let scriptMatch: object | null;
    let scriptCount = 0;
    let hasAssign = 0;
    let lastScriptLen = 0;
    while ((scriptMatch = scriptRegex.exec(html)) !== null) {
      const scriptContent = (scriptMatch as RegExpExecArray)[1];
      scriptCount++;
      lastScriptLen = scriptContent.length;
      if (!scriptContent) {
        continue;
      }
      // 查找 currentSemester 赋值位置
      const assignMatch = scriptContent.match(/(?:var|let|const|window\.)\s*currentSemester\s*=\s*/);
      if (!assignMatch || assignMatch.index === undefined) {
        continue;
      }
      hasAssign++;
      let cursor = assignMatch.index + assignMatch[0].length;
      // 跳过空白
      while (cursor < scriptContent.length && scriptContent[cursor] <= ' ') {
        cursor++;
      }
      // 处理 JSON.parse('...') 格式
      if (scriptContent.startsWith('JSON.parse', cursor)) {
        cursor += 'JSON.parse'.length;
        while (cursor < scriptContent.length && scriptContent[cursor] <= ' ') {
          cursor++;
        }
        if (cursor >= scriptContent.length || scriptContent[cursor] !== '(') {
          continue;
        }
        cursor++;
        while (cursor < scriptContent.length && scriptContent[cursor] <= ' ') {
          cursor++;
        }
        // 解析 JS 字符串（可能包含转义）
        const quoteChar = scriptContent[cursor];
        if (quoteChar !== '\'' && quoteChar !== '"') {
          continue;
        }
        cursor++;
        let str = '';
        let escaped = false;
        while (cursor < scriptContent.length) {
          const ch = scriptContent[cursor++];
          if (escaped) {
            if (ch === '\\' || ch === '\'' || ch === '"' || ch === '/') {
              str += ch;
            } else if (ch === 'n') {
              str += '\n';
            } else if (ch === 't') {
              str += '\t';
            } else if (ch === 'u') {
              // 简化处理：保留 unicode 转义让 JSON.parse 处理
              str += '\\u' + scriptContent.substring(cursor, cursor + 4);
              cursor += 4;
            } else {
              str += '\\' + ch;
            }
            escaped = false;
          } else if (ch === '\\') {
            escaped = true;
          } else if (ch === quoteChar) {
            // 跳过闭合括号
            while (cursor < scriptContent.length && scriptContent[cursor] <= ' ') {
              cursor++;
            }
            if (cursor < scriptContent.length && scriptContent[cursor] === ')') {
              return str;
            }
            break;
          } else {
            str += ch;
          }
        }
        continue;
      }
      // 直接对象赋值格式：var currentSemester = {...}
      const json = this.extractBalancedJson(scriptContent, cursor);
      if (json !== undefined) {
        return json;
      }
    }
    hilog.error(0x0000, 'AHUTong',
      'extractFail scriptCount=%{public}d hasAssign=%{public}d lastScriptLen=%{public}d htmlLen=%{public}d',
      scriptCount, hasAssign, lastScriptLen, html.length);
    return undefined;
  }

  private parseCurrentSemester(html: string): AppResult<CurrentSemester> {
    const json = this.extractCurrentSemesterJson(html);
    if (json === undefined) {
      hilog.error(0x0000, 'AHUTong',
        'parseFail htmlLen=%{public}d hasScript=%{public}d hasCS=%{public}d hasLt=%{public}d head=%{public}s',
        html.length, html.includes('<script'), html.includes('currentSemester'),
        /name=["']lt["']/i.test(html), html.substring(0, 600));
      return failure<CurrentSemester>(AppErrorKind.PARSE, '无法解析当前学期');
    }
    try {
      // currentSemester 是 JavaScript 对象字面量，使用单引号而非双引号
      // 安卓原项目用 Gson 解析（宽松），鸿蒙需将单引号替换为双引号再 JSON.parse
      const normalized = json.split('\'').join('"');
      return success<CurrentSemester>(JSON.parse(normalized) as CurrentSemester);
    } catch (e) {
      return failure<CurrentSemester>(AppErrorKind.PARSE, '当前学期数据格式异常');
    }
  }

  private mapCourses(response: CourseTableResponse): Array<Course> {
    const tables = response.studentTableVms ?? [];
    const activities = tables.length > 0 ? tables[0].activities ?? [] : [];
    const courses: Array<Course> = [];
    for (let index = 0; index < activities.length; index++) {
      const activity = activities[index];
      const weeks = (activity.weekIndexes ?? []).slice().sort((left: number, right: number) => left - right);
      if (weeks.length === 0) {
        continue;
      }
      const startUnit = activity.startUnit ?? 0;
      const endUnit = activity.endUnit ?? startUnit;
      courses.push({
        name: activity.courseName ?? '',
        courseId: activity.lessonId?.toString() ?? '',
        location: activity.room ?? '未知',
        teacher: (activity.teacherNames ?? []).join(', '),
        weekday: (activity.weekday ?? 0).toString(),
        startWeek: weeks[0].toString(),
        endWeek: weeks[weeks.length - 1].toString(),
        startTime: startUnit.toString(),
        length: Math.max(0, endUnit - startUnit + 1).toString(),
        weekIndexes: weeks
      });
    }
    return courses;
  }

  private async fetchScheduleOffset(offset: number): Promise<AppResult<Array<Course>>> {
    const page = await this.client.getText(`${CrawlerScheduleSource.BASE_URL}/student/for-std/course-table`);
    if (!page.isSuccess || page.data === undefined) {
      return failure<Array<Course>>(
        page.error?.kind ?? AppErrorKind.UNKNOWN,
        page.error?.message ?? '获取课表学期失败',
        page.error?.code
      );
    }
    const semester = this.parseCurrentSemester(page.data);
    if (!semester.isSuccess || !semester.data) {
      return failure<Array<Course>>(
        semester.error?.kind ?? AppErrorKind.PARSE,
        semester.error?.message ?? '无法解析当前学期'
      );
    }
    const id = semester.data.id;
    const pathId = id + offset;
    const url = `${CrawlerScheduleSource.BASE_URL}/student/for-std/course-table/semester/${pathId}/print-data` +
      `?semesterId=${id}&hasExperiment=false`;
    const response = await this.client.getJson<CourseTableResponse>(url);
    if (!response.isSuccess || !response.data) {
      return failure<Array<Course>>(
        response.error?.kind ?? AppErrorKind.UNKNOWN,
        response.error?.message ?? '获取课表失败',
        response.error?.code
      );
    }
    return success<Array<Course>>(this.mapCourses(response.data));
  }

  async fetchSchedule(): Promise<AppResult<Array<Course>>> { return this.fetchScheduleOffset(0); }
  async fetchNextSchedule(): Promise<AppResult<Array<Course>>> { return this.fetchScheduleOffset(20); }
}

export class DefaultScheduleRepository implements ScheduleRepository {
  private readonly source: CrawlerScheduleSource;

  constructor(source: CrawlerScheduleSource = new CrawlerScheduleSource()) {
    this.source = source;
  }

  async getSchedule(refresh: boolean = false): Promise<AppResult<Array<Course>>> {
    const schoolYear = AhuCache.getSchoolYear();
    const rawTerm = AhuCache.getSchoolTerm();
    if (!AhuCache.isLogin() || !schoolYear || !rawTerm) {
      return failure<Array<Course>>(AppErrorKind.AUTHENTICATION, '请先登录并完成学期设置');
    }
    const schoolTerm = rawTerm.startsWith(`${schoolYear}-`)
      ? rawTerm.substring(schoolYear.length + 1)
      : rawTerm;
    if (AhuCache.getMockData()) {
      const scenario = AhuCache.getMockScenario();
      if (scenario === 'network_error') return failure<Array<Course>>(AppErrorKind.HTTP, 'Mock 场景：接口返回 500', 500);
      if (scenario === 'expired_login') return failure<Array<Course>>(AppErrorKind.AUTHENTICATION, 'Mock 场景：登录状态已过期', 401);
      return success<Array<Course>>(AhuCache.getSchedule(schoolYear, schoolTerm));
    }
    if (!refresh) {
      const cached = AhuCache.getSchedule(schoolYear, schoolTerm);
      if (cached.length > 0) {
        return success<Array<Course>>(cached);
      }
    }
    const remote = await this.source.fetchSchedule();
    if (remote.isSuccess && remote.data) {
      AhuCache.saveSchedule(schoolYear, schoolTerm, remote.data);
      ScheduleReminderCoordinatorProvider.get().reschedule();
      ScheduleWidgetCoordinatorProvider.get().update();
    }
    return remote;
  }

  async getNextSchedule(refresh: boolean = false): Promise<AppResult<Array<Course>>> {
    if (!AhuCache.isLogin()) {
      return failure<Array<Course>>(AppErrorKind.AUTHENTICATION, '请先登录');
    }
    if (AhuCache.getMockData()) return success<Array<Course>>([]);
    if (!refresh) {
      const cached = AhuCache.getNextSchedule();
      if (cached !== undefined) return success<Array<Course>>(cached);
    }
    const remote = await this.source.fetchNextSchedule();
    if (remote.isSuccess && remote.data) AhuCache.saveNextSchedule(remote.data);
    return remote;
  }
}

export class ScheduleRepositoryProvider {
  private static readonly repository: ScheduleRepository = new DefaultScheduleRepository();

  static get(): ScheduleRepository {
    return ScheduleRepositoryProvider.repository;
  }
}
