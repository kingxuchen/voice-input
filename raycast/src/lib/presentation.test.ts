import { Icon } from "@raycast/api";
import { describe, expect, it } from "vitest";

import {
  BREW_COMMAND,
  INSTALL_COMMAND,
  INSTALLATION_GUIDE,
} from "./constants";
import { stringsFor, type Strings } from "./i18n";
import {
  emptyStateFor,
  toState,
  type State,
} from "./presentation";
import type { AudioDevice, CliResult, DeviceListResponse } from "./types";

const zh = stringsFor("zh-CN");
const en = stringsFor("en-US");

const devices: AudioDevice[] = [
  {
    id: 177,
    name: "vRemoteDr 2ch",
    displayName: "vRemoteDr 2ch",
    isDefault: true,
  },
  {
    id: 93,
    name: "MacBook Pro麦克风",
    displayName: "MacBook Pro麦克风",
    isDefault: false,
  },
];

/** 收窄调用形状：只有「过滤后还剩几条」和「搜索词」会影响判定。 */
function emptyFor(
  state: State,
  visibleCount: number,
  query = "",
  t: Strings = zh,
) {
  return emptyStateFor(state, { visibleCount, query }, t);
}

describe("toState", () => {
  it("ok 带设备时进入 ready", () => {
    const result: CliResult<DeviceListResponse> = {
      kind: "ok",
      value: { protocol: 1, devices },
    };

    expect(toState(result)).toEqual({ kind: "ready", devices });
  });

  it("ok 但一台设备都没有也是 ready，不是 failed", () => {
    const result: CliResult<DeviceListResponse> = {
      kind: "ok",
      value: { protocol: 1, devices: [] },
    };

    expect(toState(result)).toEqual({ kind: "ready", devices: [] });
  });

  it("其余结果各自一一对应，不互相吞并", () => {
    expect(toState({ kind: "missing" })).toEqual({ kind: "missing" });
    expect(toState({ kind: "timeout" })).toEqual({ kind: "timeout" });
    expect(
      toState({ kind: "failed", code: "hal_error" }),
    ).toEqual({ kind: "failed" });
    expect(
      toState({ kind: "outdated", direction: "app", detail: "x" }),
    ).toEqual({ kind: "outdated", direction: "app" });
    expect(
      toState({ kind: "outdated", direction: "plugin", detail: "x" }),
    ).toEqual({ kind: "outdated", direction: "plugin" });
  });
});

describe("emptyStateFor 不画空态的两种情形", () => {
  it("加载中返回 null：否则每次刷新都会闪一下「没有设备」", () => {
    expect(emptyFor({ kind: "loading" }, 0)).toBeNull();
  });

  it("ready 且过滤后仍有条目时返回 null", () => {
    expect(emptyFor({ kind: "ready", devices }, devices.length)).toBeNull();
    expect(emptyFor({ kind: "ready", devices }, 1, "black")).toBeNull();
  });
});

describe("emptyStateFor 的安装空态（缺 CLI）", () => {
  it("给的是安装引导，不是错误页", () => {
    const spec = emptyFor({ kind: "missing" }, 0);

    expect(spec).toMatchObject({
      icon: Icon.Download,
      title: zh.emptyTitle,
      description: zh.emptyDescription,
    });
  });

  it("五条动作按「复制命令 → 打开指南 → 重试 → 设置」排列", () => {
    const spec = emptyFor({ kind: "missing" }, 0);

    expect(spec?.actions.map((action) => action.intent)).toEqual([
      "copy",
      "copy",
      "openUrl",
      "retry",
      "preferences",
    ]);
  });

  it("两条复制命令各带可粘贴内容，Homebrew 那条不再漏回英文", () => {
    const spec = emptyFor({ kind: "missing" }, 0, "", en);
    const [install, brew, guide] = spec!.actions;

    expect(install).toEqual({
      intent: "copy",
      title: en.copyInstallCommand,
      content: INSTALL_COMMAND,
    });
    expect(brew).toEqual({
      intent: "copy",
      title: en.copyBrewCommand,
      content: BREW_COMMAND,
    });
    expect(guide).toEqual({
      intent: "openUrl",
      title: en.openInstallationGuide,
      url: INSTALLATION_GUIDE,
    });
  });
});

describe("emptyStateFor 的故障空态", () => {
  it("超时与读不到各有自己的文案", () => {
    expect(emptyFor({ kind: "timeout" }, 0)).toMatchObject({
      icon: Icon.Warning,
      title: zh.timedOut,
    });
    expect(emptyFor({ kind: "failed" }, 0)).toMatchObject({
      icon: Icon.Warning,
      title: zh.cannotReadDevices,
    });
  });

  it("故障空态只有重试与设置两条出口", () => {
    expect(
      emptyFor({ kind: "failed" }, 0)?.actions.map((action) => action.intent),
    ).toEqual(["retry", "preferences"]);
  });

  it("「读不到设备」和「一台设备都没有」不是同一句话", () => {
    const failed = emptyFor({ kind: "failed" }, 0, "", en)!;
    const noDevices = emptyFor({ kind: "ready", devices: [] }, 0, "", en)!;

    expect(failed.title).toBe(en.cannotReadDevices);
    expect(noDevices.title).toBe(en.noDevices);
    expect(failed.title).not.toBe(noDevices.title);
    expect(failed.icon).not.toBe(noDevices.icon);
  });
});

describe("emptyStateFor 的版本过旧两种方向", () => {
  it("App 太旧：重试 + 复制安装命令 + 设置", () => {
    const spec = emptyFor({ kind: "outdated", direction: "app" }, 0);

    expect(spec).toMatchObject({
      icon: Icon.ExclamationMark,
      title: zh.outdated,
    });
    expect(spec?.actions.map((action) => action.intent)).toEqual([
      "retry",
      "copy",
      "preferences",
    ]);
    expect(spec?.actions[1]).toEqual({
      intent: "copy",
      title: zh.copyInstallCommand,
      content: INSTALL_COMMAND,
    });
  });

  it("插件太旧：给「更新扩展」而不是安装命令，文案也不同", () => {
    const spec = emptyFor({ kind: "outdated", direction: "plugin" }, 0);

    expect(spec).toMatchObject({
      icon: Icon.ExclamationMark,
      title: zh.pluginOutdated,
    });
    expect(spec?.actions.map((action) => action.intent)).toEqual([
      "retry",
      "preferences",
      "preferences",
    ]);
    expect(spec?.actions[1]).toEqual({
      intent: "preferences",
      title: zh.updateExtension,
      icon: Icon.Download,
    });
    expect(zh.pluginOutdated).not.toBe(zh.outdated);
  });
});

describe("emptyStateFor 的 ready 两种空态", () => {
  it("「HAL 答没有设备」只给重试", () => {
    const spec = emptyFor({ kind: "ready", devices: [] }, 0);

    expect(spec).toMatchObject({
      icon: Icon.Microphone,
      title: zh.noDevices,
    });
    expect(spec?.actions.map((action) => action.intent)).toEqual(["retry"]);
  });

  it("有设备但搜不到：回显查询词，并给「清空搜索」出口", () => {
    const spec = emptyFor({ kind: "ready", devices }, 0, "airpods");

    expect(spec).toMatchObject({
      icon: Icon.MagnifyingGlass,
      title: zh.noMatches,
      description: "airpods",
    });
    expect(spec?.actions.map((action) => action.intent)).toEqual([
      "clearSearch",
      "retry",
    ]);
  });

  it("设备总数只认 state，不认调用方另传的条数", () => {
    // state 里一台都没有：即使调用方说“看得见 3 条”，也只能是「没有设备」空态。
    expect(emptyFor({ kind: "ready", devices: [] }, 3)?.title).toBe(
      zh.noDevices,
    );
    // 反过来，state 里有设备而过滤后为 0：只能是「搜不到」空态。
    expect(emptyFor({ kind: "ready", devices }, 0, "x")?.title).toBe(
      zh.noMatches,
    );
  });
});
