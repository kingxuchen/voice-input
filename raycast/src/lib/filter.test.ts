import { describe, expect, it } from "vitest";

import { filterDevices } from "./filter";
import type { AudioDevice } from "./types";

const devices: AudioDevice[] = [
  {
    id: 1,
    name: "BlackHole 2ch",
    displayName: "BlackHole 2ch",
    isDefault: false,
  },
  {
    id: 2,
    name: "BlackHole 16ch",
    displayName: "BlackHole 16ch",
    isDefault: false,
  },
  {
    id: 3,
    name: "MacBook Pro麦克风",
    displayName: "MacBook Pro麦克风",
    isDefault: true,
  },
  { id: 4, name: "麦克风", displayName: "麦克风 2", isDefault: false },
];

describe("filterDevices", () => {
  it("空查询返回全部，保持 HAL 原序", () => {
    expect(filterDevices(devices, "").map((d) => d.id)).toEqual([1, 2, 3, 4]);
    expect(filterDevices(devices, "   ").map((d) => d.id)).toEqual([
      1, 2, 3, 4,
    ]);
  });

  it("忽略大小写匹配设备名", () => {
    expect(filterDevices(devices, "black").map((d) => d.id)).toEqual([1, 2]);
    expect(filterDevices(devices, "BLACKHOLE 16").map((d) => d.id)).toEqual([
      2,
    ]);
  });

  it("中文名可搜（含系统原文里的中文）", () => {
    expect(filterDevices(devices, "麦克风").map((d) => d.id)).toEqual([3, 4]);
    expect(filterDevices(devices, "macbook").map((d) => d.id)).toEqual([3]);
  });

  it("displayName 也参与匹配（同名设备的序号可搜）", () => {
    const query = "麦克风 2";
    expect(filterDevices(devices, query).map((d) => d.id)).toEqual([4]);
  });

  it("无匹配时返回空数组，而不是回退成全量", () => {
    expect(filterDevices(devices, "airpods")).toEqual([]);
  });
});
