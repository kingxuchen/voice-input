import { describe, expect, it } from "vitest";

import { ROOT_SEARCH_GRACE_MS, shouldDropSearchText } from "./searchText";

describe("shouldDropSearchText", () => {
  it("挂载后极短窗口内的推送是根搜索词的回声，必须丢弃", () => {
    expect(shouldDropSearchText(1000, 1000)).toBe(true);
    expect(shouldDropSearchText(1000, 1399)).toBe(true);
  });

  it("窗口一满就接受，之后的都是用户真实输入", () => {
    expect(shouldDropSearchText(1000, 1000 + ROOT_SEARCH_GRACE_MS)).toBe(
      false,
    );
    expect(shouldDropSearchText(1000, 5000)).toBe(false);
  });

  it("系统时钟被回拨（now 早于挂载时刻）时也丢弃", () => {
    expect(shouldDropSearchText(5000, 1000)).toBe(true);
  });

  it("窗口是 400ms：改这个数必须连带重做 0023 里的真机结论", () => {
    expect(ROOT_SEARCH_GRACE_MS).toBe(400);
  });
});
