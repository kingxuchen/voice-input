import { describe, expect, it } from "vitest";

import { parseDeviceList } from "./cli";

const ok = JSON.stringify({
  protocol: 1,
  devices: [
    {
      id: 93,
      name: "MacBook Pro麦克风",
      displayName: "MacBook Pro麦克风",
      isDefault: false,
    },
    {
      id: 177,
      name: "vRemoteDr 2ch",
      displayName: "vRemoteDr 2ch",
      isDefault: true,
    },
  ],
});

describe("parseDeviceList", () => {
  it("契约形状原样映射，含同名序号 displayName", () => {
    const result = parseDeviceList(ok);
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.value.devices.map((d) => d.displayName)).toEqual([
      "MacBook Pro麦克风",
      "vRemoteDr 2ch",
    ]);
    expect(
      result.value.devices.filter((d) => d.isDefault).map((d) => d.id),
    ).toEqual([177]);
  });

  it("保持 HAL 原序，不排序", () => {
    const result = parseDeviceList(
      JSON.stringify({
        protocol: 1,
        devices: [
          { id: 3, name: "z", displayName: "z", isDefault: false },
          { id: 1, name: "a", displayName: "a", isDefault: true },
          { id: 2, name: "m", displayName: "m 2", isDefault: false },
        ],
      }),
    );
    expect(
      result.kind === "ok" && result.value.devices.map((d) => d.id),
    ).toEqual([3, 1, 2]);
  });

  it("protocol 不认识 → outdated（旧 App 或插件太旧）", () => {
    expect(
      parseDeviceList(JSON.stringify({ protocol: 2, devices: [] })).kind,
    ).toBe("outdated");
    expect(parseDeviceList(JSON.stringify({ devices: [] })).kind).toBe(
      "outdated",
    );
  });

  it("非法 JSON 与字段缺失 → outdated，不崩", () => {
    expect(parseDeviceList("not json").kind).toBe("outdated");
    expect(
      parseDeviceList(
        JSON.stringify({ protocol: 1, devices: [{ id: "93" }] }),
      ).kind,
    ).toBe("outdated");
  });

  it("结构化错误映射到契约错误码", () => {
    const result = parseDeviceList(
      JSON.stringify({
        protocol: 1,
        error: { code: "device_not_found", message: "gone" },
      }),
    );
    expect(result).toEqual({
      kind: "failed",
      code: "device_not_found",
    });
  });

  it("未知错误码归为 unknown，不伪造语义", () => {
    const result = parseDeviceList(
      JSON.stringify({ protocol: 1, error: { code: "wat" } }),
    );
    expect(result.kind).toBe("outdated");
  });
});
