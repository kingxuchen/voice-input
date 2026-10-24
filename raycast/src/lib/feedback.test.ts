import { describe, expect, it } from "vitest";

import { switchFeedback } from "./feedback";
import { stringsFor } from "./i18n";
import type { AudioDevice } from "./types";

const t = stringsFor("zh-Hans-CN");
const device: AudioDevice = {
  id: 93,
  name: "MacBook Pro麦克风",
  displayName: "MacBook Pro麦克风",
  isDefault: false,
};

describe("switchFeedback", () => {
  it("成功 → 用回读状态刷新列表，提示的是回读后的默认设备", () => {
    const result = switchFeedback(
      { kind: "ok", value: { protocol: 1, devices: [device] } },
      device,
      t,
    );
    expect(result).toEqual({
      kind: "ok",
      devices: [device],
      message: "已切换到 MacBook Pro麦克风",
    });
  });

  it("系统回落到别的设备时，提示按回读结果报，不照抄用户点的那台", () => {
    const fallback: AudioDevice = {
      id: 177,
      name: "vRemoteDr 2ch",
      displayName: "vRemoteDr 2ch",
      isDefault: true,
    };
    const result = switchFeedback(
      { kind: "ok", value: { protocol: 1, devices: [fallback] } },
      device,
      t,
    );
    expect(result).toEqual({
      kind: "ok",
      devices: [fallback],
      message: "已切换到 vRemoteDr 2ch",
    });
  });

  it("设备已消失 → 要求重读列表，并给出明确提示", () => {
    const result = switchFeedback(
      { kind: "failed", code: "device_not_found", detail: "device_not_found" },
      device,
      t,
    );
    expect(result).toEqual({
      kind: "reload",
      message: "设备已断开，列表已刷新",
    });
  });

  it("写入失败 → 也要重读列表（系统可能已变），并提示切换失败", () => {
    const result = switchFeedback(
      { kind: "failed", code: "switch_failed", detail: "switch_failed" },
      device,
      t,
    );
    expect(result).toEqual({ kind: "reload", message: "切换输入失败" });
  });

  it("bad_usage 属于插件自身问题，提示失败但不重读", () => {
    const result = switchFeedback(
      { kind: "failed", code: "bad_usage", detail: "bad_usage" },
      device,
      t,
    );
    expect(result).toEqual({ kind: "failed", message: "切换输入失败" });
  });

  it("超时/缺 CLI/版本不兼容也走失败提示，不静默", () => {
    expect(switchFeedback({ kind: "timeout" }, device, t)).toEqual({
      kind: "failed",
      message: "切换输入失败",
    });
    expect(switchFeedback({ kind: "missing" }, device, t)).toEqual({
      kind: "failed",
      message: "切换输入失败",
    });
    expect(
      switchFeedback(
        { kind: "outdated", direction: "app", detail: "x" },
        device,
        t,
      ),
    ).toEqual({
      kind: "failed",
      message: "切换输入失败",
    });
  });
});
