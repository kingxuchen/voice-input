/** Vitest 用的 `@raycast/api` 桩：只覆盖被测代码触碰到的部分。 */

export function getPreferenceValues(): Record<string, unknown> {
  return {};
}

export const Icon = {} as Record<string, unknown>;
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
