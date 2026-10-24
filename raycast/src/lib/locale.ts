import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

/**
 * 系统语言探测。
 *
 * 不能用 `Intl.DateTimeFormat().resolvedOptions().locale`：Raycast 的 Node 运行时在本机（系统为中文）
 * 报的是 `en-CN-u-ca-gregory-hc-h23`——基础语言被解析成 `en`，中文系统也会被判成英文（真机实证）。
 * 因此读 macOS 自己的语言偏好 `AppleLanguages`，它的首项就是「语言与地区」里排在第一的语言。
 */
export async function systemLocale(): Promise<string | undefined> {
  try {
    const { stdout } = await run("defaults", ["read", "-g", "AppleLanguages"], {
      timeout: 1000,
    });
    const first = stdout.match(/"([^"]+)"/)?.[1];
    return first;
  } catch {
    return undefined;
  }
}
