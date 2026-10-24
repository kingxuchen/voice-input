import type { Strings } from "./i18n";
import type { AudioDevice, CliResult, DeviceListResponse } from "./types";

/**
 * 切换动作的结果判定：把「CLI 说了什么」翻译成「界面该做什么」。
 *
 * 抽成纯函数是因为这层判定最容易被 GUI 手验漏掉（尤其"设备刚消失""系统回落"这类竞态），
 * 而它又不依赖 React；`switchTo` 只负责执行判定结果。
 */
export type SwitchFeedback =
  | { kind: "ok"; devices: AudioDevice[]; message: string }
  | { kind: "reload"; message: string }
  | { kind: "failed"; message: string };

export function switchFeedback(
  result: CliResult<DeviceListResponse>,
  device: AudioDevice,
  t: Strings,
): SwitchFeedback {
  if (result.kind === "ok") {
    // 用回读状态而不是本地改 isDefault：系统可能拒绝、回落或另有变化。
    // 连提示里的设备名也取自回读结果，不能照抄用户点的那台。
    const active = result.value.devices.find(
      (candidate) => candidate.isDefault,
    );
    return {
      kind: "ok",
      devices: result.value.devices,
      message: t.switchedTo(active?.displayName ?? device.displayName),
    };
  }

  if (result.kind === "failed" && result.code === "device_not_found") {
    return { kind: "reload", message: t.deviceDisconnected };
  }

  if (result.kind === "failed" && result.code === "switch_failed") {
    // 写入报错时系统状态未必没变（HAL 可能已切走），重读一次再说。
    return { kind: "reload", message: t.switchFailed };
  }

  // bad_usage / hal_error / 超时 / 缺 CLI / 版本不兼容：重读也解决不了，直接提示。
  return { kind: "failed", message: t.switchFailed };
}
