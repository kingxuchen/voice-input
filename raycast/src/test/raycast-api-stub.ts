/** Vitest 用的 `@raycast/api` 桩：只覆盖被测代码触碰到的部分。 */

export function getPreferenceValues(): Record<string, unknown> {
  return {};
}

/**
 * 图标桩给真实字符串而不是空对象：空对象下所有图标都是 `undefined`，
 * 「装没装 App」和「读不到设备」用不同图标这件事就断言不出来。
 * 只需要覆盖被测代码实际引用到的图标名，多一个少一个不影响。
 */
export const Icon = {
  ArrowClockwise: "arrow-clockwise",
  CheckCircle: "check-circle",
  Download: "download",
  ExclamationMark: "exclamation-mark",
  Gear: "gear",
  MagnifyingGlass: "magnifying-glass",
  Microphone: "microphone",
  Warning: "warning",
  XMarkCircle: "x-mark-circle",
} as Record<string, unknown>;
export const Toast = {
  Style: { Success: "success", Failure: "failure" },
} as Record<string, unknown>;

export async function showToast(): Promise<void> {}
export async function showHUD(): Promise<void> {}
export async function closeMainWindow(): Promise<void> {}
export async function openExtensionPreferences(): Promise<void> {}

export const Action = {} as Record<string, unknown>;
export const ActionPanel = {} as Record<string, unknown>;
export const List = {} as Record<string, unknown>;
