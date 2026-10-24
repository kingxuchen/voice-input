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

export type VersionResponse = {
  protocol: number;
  appVersion: string;
};

export type ErrorCode =
  "bad_usage" | "hal_error" | "device_not_found" | "switch_failed";

export type ErrorResponse = {
  protocol: number;
  error: { code: ErrorCode; message: string };
};

/**
 * 调用结果的判别联合。`outdated` 覆盖「JSON 不合法」与「protocol 不认识」两种，
 * 因为它们对用户的含义相同：这台机器上的 VoiceInput 跟插件说不上话。
 */
export type CliResult<T> =
  | { kind: "ok"; value: T }
  | { kind: "missing" }
  | { kind: "timeout" }
  | { kind: "outdated"; detail: string }
  | { kind: "failed"; code: ErrorCode | "unknown"; detail: string };
