import { describe, expect, it } from "vitest";

import { stringsFor } from "./i18n";

describe("stringsFor", () => {
  it("中文系统用中文文案", () => {
    expect(stringsFor("zh-Hans-CN").current).toBe("当前");
    expect(stringsFor("zh_CN").switchedTo("BlackHole 2ch")).toBe(
      "已切换到 BlackHole 2ch",
    );
  });

  it("其余语言用英文文案", () => {
    expect(stringsFor("en-US").current).toBe("Current");
    expect(stringsFor("ja-JP").switchedTo("BlackHole 2ch")).toBe(
      "Switched to BlackHole 2ch",
    );
    expect(stringsFor(undefined).current).toBe("Current");
  });
});
