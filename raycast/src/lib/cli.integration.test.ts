import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterAll, describe, expect, it } from "vitest";

import { listDevices, resolveCliPath, setDefault } from "./cli";

const sandboxes: string[] = [];

afterAll(() => {
  for (const dir of sandboxes) rmSync(dir, { recursive: true, force: true });
});

/** 造一个可执行桩：真实子进程、真实退出码，不 mock child_process。 */
function stub(script: string): string {
  const dir = mkdtempSync(join(tmpdir(), "voiceinput-cli-"));
  sandboxes.push(dir);
  const path = join(dir, "voiceinput-cli");
  writeFileSync(path, `#!/bin/sh\n${script}\n`);
  chmodSync(path, 0o755);
  return path;
}

const OK_LIST = `{"protocol":1,"devices":[{"id":177,"name":"vRemoteDr 2ch","displayName":"vRemoteDr 2ch","isDefault":true}]}`;

describe("listDevices 的错误面", () => {
  it("protocol 更高 → outdated/plugin（该更新扩展）", async () => {
    const path = stub(`echo '{"protocol":2,"devices":[]}'`);
    expect(await listDevices(path)).toEqual({
      kind: "outdated",
      direction: "plugin",
      detail: "protocol 2 is not 1",
    });
  });

  it("protocol 更低 → outdated/app（该升级伴侣 App）", async () => {
    const path = stub(`echo '{"protocol":0,"devices":[]}'`);
    const result = await listDevices(path);
    expect(result.kind === "outdated" && result.direction).toBe("app");
  });

  it("非 JSON 输出 → outdated/app，不抛异常", async () => {
    const path = stub(`echo 'not json'`);
    const result = await listDevices(path);
    expect(result.kind === "outdated" && result.direction).toBe("app");
  });

  it("结构化错误按 code 映射，不解析 stdout 文本", async () => {
    const path = stub(
      `echo '{"protocol":1,"error":{"code":"hal_error","message":"boom"}}'; exit 3`,
    );
    expect(await listDevices(path)).toEqual({
      kind: "failed",
      code: "hal_error",
      detail: "hal_error",
    });
  });

  it("bad_usage 也按 code 透传（插件自身问题）", async () => {
    const path = stub(
      `echo '{"protocol":1,"error":{"code":"bad_usage","message":"usage"}}'; exit 2`,
    );
    expect(await listDevices(path)).toEqual({
      kind: "failed",
      code: "bad_usage",
      detail: "bad_usage",
    });
  });
});

describe("setDefault 的错误面", () => {
  it("把设备 id 原样传给 helper，并返回回读状态", async () => {
    const argsFile = join(
      mkdtempSync(join(tmpdir(), "voiceinput-args-")),
      "args",
    );
    sandboxes.push(argsFile);
    const path = stub(`echo "$@" > '${argsFile}'; echo '${OK_LIST}'`);

    const result = await setDefault(177, path);

    expect(readFileSync(argsFile, "utf8").trim()).toBe("set-default 177");
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.value.devices).toHaveLength(1);
    expect(result.value.devices[0].isDefault).toBe(true);
  });

  it("设备已消失 → device_not_found（界面重读 + 提示）", async () => {
    const path = stub(
      `echo '{"protocol":1,"error":{"code":"device_not_found","message":"gone"}}'; exit 4`,
    );
    expect(await setDefault(93, path)).toEqual({
      kind: "failed",
      code: "device_not_found",
      detail: "device_not_found",
    });
  });

  it("写入失败 → switch_failed", async () => {
    const path = stub(
      `echo '{"protocol":1,"error":{"code":"switch_failed","message":"nope"}}'; exit 4`,
    );
    expect(await setDefault(93, path)).toEqual({
      kind: "failed",
      code: "switch_failed",
      detail: "switch_failed",
    });
  });
});

describe("resolveCliPath 探测顺序", () => {
  it("任何候选都找不到时解析为 null（调用方据此进安装空态）", async () => {
    expect(await resolveCliPath(undefined, [])).toBeNull();
    expect(
      await resolveCliPath(
        join(tmpdir(), "definitely-not-here", "voiceinput-cli"),
        [],
      ),
    ).toBeNull();
  });

  it("偏好路径不可用时回退到候选列表，而不是直接报缺失", async () => {
    const path = stub(`echo '${OK_LIST}'`);
    expect(
      await resolveCliPath(
        join(tmpdir(), "definitely-not-here", "voiceinput-cli"),
        [path],
      ),
    ).toBe(path);
  });

  it("偏好路径可用时优先用它", async () => {
    const preferred = stub(`echo '${OK_LIST}'`);
    const other = stub(`echo '${OK_LIST}'`);
    expect(await resolveCliPath(preferred, [other])).toBe(preferred);
  });
});
