/** VoiceInput CLI 协议类型（冻结于 .issues/0017-cli-contract.md） */

export const PROTOCOL_VERSION = 1;

export type AudioDevice = {
  id: number;
  name: string;
  displayName: string;
  isDefault: boolean;
};

export type DeviceListResponse = {
  protocol: number;
  devices: AudioDevice[];
};

/**
 * 契约 v1 的全部错误码，唯一的定义处：`ErrorCode` 与运行时校验都用这一份，
 * 新增码只改这里，不会出现「类型里有、校验表里没有」的漂移。
 */
export const ERROR_CODES = [
  "bad_usage",
  "hal_error",
  "device_not_found",
  "switch_failed",
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/**
 * 调用结果的判别联合。`outdated` 覆盖「JSON 不合法」与「protocol 不认识」两种，
 * 因为它们对用户的含义相同：这台机器上的 VoiceInput 跟插件说不上话。
 *
 * `failed` 只带语义 `code`（界面据此决定重读还是报错）。CLI 的诊断串（属性四字符码 + OSStatus）
 * 走 stderr，不复制进这里：插件不解析 stdout 文本，多存一份只会与真实原因漂移。
 */
export type CliResult<T> =
  | { kind: "ok"; value: T }
  | { kind: "missing" }
  | { kind: "timeout" }
  | { kind: "outdated"; direction: "app" | "plugin"; detail: string }
  | { kind: "failed"; code: ErrorCode | "unknown" };
