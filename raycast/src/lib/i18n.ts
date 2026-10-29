/** 自有 UI 文案：manifest 元数据是静态英文（Raycast 无 per-locale），这里按系统语言切换。 */

export type Strings = {
  emptyTitle: string;
  emptyDescription: string;
  copyInstallCommand: string;
  copyBrewCommand: string;
  openInstallationGuide: string;
  retry: string;
  openPreferences: string;
  switchedTo: (name: string) => string;
  deviceDisconnected: string;
  switchFailed: string;
  cannotReadDevices: string;
  noDevices: string;
  timedOut: string;
  outdated: string;
  pluginOutdated: string;
  updateExtension: string;
  current: string;
  noMatches: string;
  clearSearch: string;
  switchToThisInput: string;
  refresh: string;
  copyDeviceName: string;
  openSoundSettings: string;
  openVoiceInput: string;
};

const en: Strings = {
  emptyTitle: "VoiceInput Not Installed",
  emptyDescription:
    "Install the VoiceInput companion app to list and switch audio inputs.",
  copyInstallCommand: "Copy Install Command",
  copyBrewCommand: "Copy Homebrew Command",
  openInstallationGuide: "Open Installation Guide",
  retry: "Retry",
  openPreferences: "Open Extension Preferences",
  switchedTo: (name) => `Switched to ${name}`,
  deviceDisconnected: "Device disconnected — list refreshed",
  switchFailed: "Could not switch input",
  cannotReadDevices: "Cannot read audio devices",
  noDevices: "No input devices found",
  timedOut: "Reading devices timed out",
  outdated: "VoiceInput is out of date",
  pluginOutdated: "This extension is out of date",
  updateExtension: "Update Extension",
  current: "Current",
  noMatches: "No matching devices",
  clearSearch: "Clear Search",
  switchToThisInput: "Switch to This Input",
  refresh: "Refresh",
  copyDeviceName: "Copy Device Name",
  openSoundSettings: "Open Sound Settings",
  openVoiceInput: "Open VoiceInput",
};

const zh: Strings = {
  emptyTitle: "未安装 VoiceInput",
  emptyDescription: "安装 VoiceInput 伴侣应用后，即可列出并切换音频输入设备。",
  copyInstallCommand: "复制安装命令",
  copyBrewCommand: "复制 Homebrew 命令",
  openInstallationGuide: "打开安装指南",
  retry: "重试",
  openPreferences: "打开扩展设置",
  switchedTo: (name) => `已切换到 ${name}`,
  deviceDisconnected: "设备已断开，列表已刷新",
  switchFailed: "切换输入失败",
  cannotReadDevices: "无法读取音频设备",
  noDevices: "未发现可用输入设备",
  timedOut: "读取设备超时",
  outdated: "VoiceInput 版本过旧",
  pluginOutdated: "插件版本过旧",
  updateExtension: "更新扩展",
  current: "当前",
  noMatches: "没有匹配的设备",
  clearSearch: "清空搜索",
  switchToThisInput: "切换到此音源",
  refresh: "刷新",
  copyDeviceName: "复制设备名称",
  openSoundSettings: "打开声音设置",
  openVoiceInput: "打开 VoiceInput",
};

/** `zh-*`（含 zh_CN）走中文，其余英文。 */
export function stringsFor(locale: string | undefined): Strings {
  return locale?.toLowerCase().startsWith("zh") ? zh : en;
}
