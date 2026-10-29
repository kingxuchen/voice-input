import { execFile, type ChildProcess } from "node:child_process";
import { constants } from "node:fs";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import { getPreferenceValues } from "@raycast/api";

import {
  ERROR_CODES,
  PROTOCOL_VERSION,
  type AudioDevice,
  type CliResult,
  type DeviceListResponse,
  type ErrorCode,
} from "./types";

const TIMEOUT_MS = 2000;
const KILL_GRACE_MS = 1000;
const MAX_BUFFER = 1024 * 1024;

/** 契约里的设备名与序号由 helper 决定；插件只做形状校验。 */
function toDeviceList(value: object): DeviceListResponse | null {
  if (!("devices" in value) || !Array.isArray(value.devices)) return null;
  const devices: AudioDevice[] = [];
  for (const raw of value.devices) {
    if (!raw || typeof raw !== "object") return null;
    if (!("id" in raw) || typeof raw.id !== "number") return null;
    if (!("name" in raw) || typeof raw.name !== "string") return null;
    if (!("displayName" in raw) || typeof raw.displayName !== "string")
      return null;
    if (!("isDefault" in raw) || typeof raw.isDefault !== "boolean")
      return null;
    devices.push({
      id: raw.id,
      name: raw.name,
      displayName: raw.displayName,
      isDefault: raw.isDefault,
    });
  }
  return { protocol: PROTOCOL_VERSION, devices };
}

function readProtocol(value: object): number | null {
  if (!("protocol" in value) || typeof value.protocol !== "number") return null;
  return value.protocol;
}

function readErrorCode(value: object): ErrorCode | null {
  if (!("error" in value) || !value.error || typeof value.error !== "object")
    return null;
  if (!("code" in value.error) || typeof value.error.code !== "string")
    return null;
  const code = value.error.code;
  return ERROR_CODES.find((candidate) => candidate === code) ?? null;
}

/** 纯解析函数：生产路径与测试都走它，不再套一层仅给测试用的同义函数。 */
export function parseDeviceList(stdout: string): CliResult<DeviceListResponse> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    return {
      kind: "outdated",
      direction: "app",
      detail: "response is not valid JSON",
    };
  }
  if (!parsed || typeof parsed !== "object") {
    return {
      kind: "outdated",
      direction: "app",
      detail: "response is not an object",
    };
  }
  const protocol = readProtocol(parsed);
  if (protocol !== PROTOCOL_VERSION) {
    // 协议更高 = 插件太旧（更新扩展）；更低或缺失 = App 太旧。两者给用户的动作不同。
    return {
      kind: "outdated",
      direction:
        typeof protocol === "number" && protocol > PROTOCOL_VERSION
          ? "plugin"
          : "app",
      detail: `protocol ${String(protocol)} is not ${PROTOCOL_VERSION}`,
    };
  }
  const errorCode = readErrorCode(parsed);
  if (errorCode) {
    return { kind: "failed", code: errorCode };
  }
  const list = toDeviceList(parsed);
  if (!list) {
    return {
      kind: "outdated",
      direction: "app",
      detail: "device list has an unexpected shape",
    };
  }
  return { kind: "ok", value: list };
}

const HELPER_RELATIVE = "VoiceInput.app/Contents/MacOS/voiceinput-cli";

function candidates(): string[] {
  return ["/Applications", join(homedir(), "Applications")].map((root) =>
    join(root, HELPER_RELATIVE),
  );
}

async function isExecutable(path: string): Promise<boolean> {
  try {
    await access(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/**
 * 偏好设置里的路径优先；留空或不可用则**回退**到候选列表（陈旧偏好不该让命令直接失效）。
 * `null` 表示都没找到——调用方据此进入安装空态。`searchPaths` 仅为测试注入。
 */
export async function resolveCliPath(
  preferencePath?: string,
  searchPaths: string[] = candidates(),
): Promise<string | null> {
  const explicit = preferencePath?.trim();
  for (const path of explicit ? [explicit, ...searchPaths] : searchPaths) {
    if (await isExecutable(path)) return path;
  }
  return null;
}

type RunOutcome =
  | { stdout: string }
  | { kind: "missing" | "timeout" }
  | { kind: "failed"; detail: string };

function run(cliPath: string, args: string[]): Promise<RunOutcome> {
  const { promise, resolve } = Promise.withResolvers<RunOutcome>();
  let settled = false;
  const settle = (outcome: RunOutcome) => {
    if (settled) return;
    settled = true;
    clearTimeout(killTimer);
    resolve(outcome);
  };

  const child: ChildProcess = execFile(
    cliPath,
    args,
    {
      timeout: TIMEOUT_MS,
      killSignal: "SIGTERM",
      maxBuffer: MAX_BUFFER,
      encoding: "utf8",
    },
    (error, stdout) => {
      if (!error) return settle({ stdout });
      const failure = error as NodeJS.ErrnoException & {
        killed?: boolean;
        code?: number | string;
      };
      if (failure.code === "ENOENT" || failure.code === "EACCES")
        return settle({ kind: "missing" });
      if (failure.killed) return settle({ kind: "timeout" });
      // 非零退出码的错误（bad_usage / hal_error / device_not_found / switch_failed）仍带 stdout。
      if (typeof failure.code === "number") return settle({ stdout });
      return settle({ kind: "failed", detail: error.message });
    },
  );

  // execFile 的 timeout 只发 SIGTERM；赖着不退就补一记 SIGKILL。
  const killTimer = setTimeout(() => {
    child.kill("SIGKILL");
    settle({ kind: "timeout" });
  }, TIMEOUT_MS + KILL_GRACE_MS);

  return promise;
}

async function call(
  cliPath: string | undefined,
  args: string[],
): Promise<RunOutcome> {
  const path = await resolveCliPath(cliPath);
  if (!path) return { kind: "missing" };
  return run(path, args);
}

/**
 * 「跑一次 → 映射」的唯一实现：有 stdout 就按契约解析，没跑起来（missing / timeout / 进程层失败）
 * 就映射成对应的结果。`list` 与 `set-default` 只差参数，不该各写一遍。
 */
async function invoke(
  args: string[],
  cliPath?: string,
): Promise<CliResult<DeviceListResponse>> {
  const outcome = await call(cliPath, args);
  if ("kind" in outcome) {
    if (outcome.kind !== "failed") return { kind: outcome.kind };
    // 进程层失败（拉不起来、无退出码）没有契约错误码可映射；原因进日志，别静默丢掉。
    console.error(`voiceinput-cli ${args.join(" ")}: ${outcome.detail}`);
    return { kind: "failed", code: "unknown" };
  }
  return parseDeviceList(outcome.stdout);
}

export function listDevices(cliPath?: string) {
  return invoke(["list"], cliPath);
}

/** 切换结果就是切换后回读的完整列表（契约 0017）。 */
export function setDefault(id: number, cliPath?: string) {
  return invoke(["set-default", String(id)], cliPath);
}

export function preferenceCliPath(): string | undefined {
  try {
    const values: unknown = getPreferenceValues();
    if (
      values &&
      typeof values === "object" &&
      "cliPath" in values &&
      typeof values.cliPath === "string"
    ) {
      return values.cliPath;
    }
    return undefined;
  } catch {
    return undefined;
  }
}
