import { Icon } from "@raycast/api";

import { BREW_COMMAND, INSTALL_COMMAND, INSTALLATION_GUIDE } from "./constants";
import type { Strings } from "./i18n";
import type { AudioDevice, CliResult, DeviceListResponse } from "./types";

/**
 * 「现在该给用户看什么」的唯一定义处：只有纯数据，没有 React、没有 CLI 调用。
 *
 * 为什么单独成层：这些判定最容易被 GUI 手验漏掉——比如「HAL 答没有设备」和「读不到设备」
 * 都要一个空态，文案却必须不同；漏掉一个分支只在真机上偶发出现。放进纯函数后，每种情况
 * 都能被 vitest 直接驱动，组件只负责把数据画出来（先例见 lib/feedback.ts）。
 */

/** 界面状态。由 CLI 结果映射而来，六种情况各自独立，没有「部分可用」的中间态。 */
export type State =
  | { kind: "loading" }
  | { kind: "ready"; devices: AudioDevice[] }
  | { kind: "missing" }
  | { kind: "timeout" }
  | { kind: "outdated"; direction: "app" | "plugin" }
  | { kind: "failed" };

/** CLI 结果 → 界面状态。缺 CLI 走安装空态，不是错误页。 */
export function toState(result: CliResult<DeviceListResponse>): State {
  switch (result.kind) {
    case "ok":
      return { kind: "ready", devices: result.value.devices };
    case "missing":
      return { kind: "missing" };
    case "timeout":
      return { kind: "timeout" };
    case "outdated":
      return { kind: "outdated", direction: result.direction };
    case "failed":
      return { kind: "failed" };
  }
}

/**
 * 空态里的一条动作。只有 `copy` / `openUrl` 自带执行方式（由对应 Action 组件完成），
 * 其余三种是「意图」，交回组件按 intent 派发——这样判定层不必知道 `setState` / `load` 的存在。
 */
export type EmptyAction =
  | { intent: "retry"; title: string; icon: Icon }
  | { intent: "clearSearch"; title: string; icon: Icon }
  | { intent: "preferences"; title: string; icon: Icon }
  | { intent: "copy"; title: string; content: string }
  | { intent: "openUrl"; title: string; url: string };

/** 需要组件自己执行的动作意图。 */
export type CommandIntent = "retry" | "clearSearch" | "preferences";

export type EmptySpec = {
  icon: Icon;
  title: string;
  description?: string;
  actions: EmptyAction[];
};

/**
 * 当前状态该显示哪个空态；返回 `null` 表示该直接画设备列表。
 *
 * @param visibleCount 过滤后的条数。设备总数取自 `state.devices` 本身——不让调用方另传一份，
 *   否则两份数据可能互相矛盾（比如传进来的总数说没有设备、状态里却有）。
 * @param query 当前搜索词，仅用于「有设备但搜不到」空态的说明行。
 */
export function emptyStateFor(
  state: State,
  view: { visibleCount: number; query: string },
  t: Strings,
): EmptySpec | null {
  const retry: EmptyAction = { intent: "retry", title: t.retry, icon: Icon.ArrowClockwise };
  const preferences: EmptyAction = { intent: "preferences", title: t.openPreferences, icon: Icon.Gear };

  switch (state.kind) {
    case "loading":
      // 数据没回来之前不画空态，否则每次刷新都会闪一下「没有设备」。
      return null;

    case "missing":
      return {
        icon: Icon.Download,
        title: t.emptyTitle,
        description: t.emptyDescription,
        actions: [
          { intent: "copy", title: t.copyInstallCommand, content: INSTALL_COMMAND },
          { intent: "copy", title: t.copyBrewCommand, content: BREW_COMMAND },
          { intent: "openUrl", title: t.openInstallationGuide, url: INSTALLATION_GUIDE },
          retry,
          preferences,
        ],
      };

    case "timeout":
      return { icon: Icon.Warning, title: t.timedOut, actions: [retry, preferences] };

    case "failed":
      return { icon: Icon.Warning, title: t.cannotReadDevices, actions: [retry, preferences] };

    case "outdated":
      // 「App 太旧」要升级伴侣 App，「插件太旧」只能更新扩展：文案和动作都不同，不能合并。
      return state.direction === "plugin"
        ? {
            icon: Icon.ExclamationMark,
            title: t.pluginOutdated,
            actions: [
              retry,
              { intent: "preferences", title: t.updateExtension, icon: Icon.Download },
              preferences,
            ],
          }
        : {
            icon: Icon.ExclamationMark,
            title: t.outdated,
            actions: [
              retry,
              { intent: "copy", title: t.copyInstallCommand, content: INSTALL_COMMAND },
              preferences,
            ],
          };

    case "ready":
      // 契约 v1：「HAL 答没有设备」是成功快照里的空列表，「读不到」才进 failed。两者文案不能混。
      if (state.devices.length === 0) {
        return { icon: Icon.Microphone, title: t.noDevices, actions: [retry] };
      }
      // 有设备但搜不到：给清空搜索的出口，别让人以为设备消失了。
      if (view.visibleCount === 0) {
        return {
          icon: Icon.MagnifyingGlass,
          title: t.noMatches,
          description: view.query,
          actions: [{ intent: "clearSearch", title: t.clearSearch, icon: Icon.XMarkCircle }, retry],
        };
      }
      return null;
  }
}
