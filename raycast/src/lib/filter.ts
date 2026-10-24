import type { AudioDevice } from "./types";

/**
 * 自己按查询过滤设备。
 *
 * 为什么不用 Raycast 的内建过滤：一旦传了 `onSearchTextChange`，`List` 的 `filtering` 默认变 false
 * （官方默认值就是「有回调则不过滤」），于是输入只会写进搜索框、列表不动。
 * 而打开 `filtering` 又会把 Raycast 从根搜索带进来的查询词当成过滤词（见 0021），
 * 所以这里接管过滤，规则只有一条：大小写不敏感的子串匹配 `name` 或 `displayName`。
 */
export function filterDevices(
  devices: AudioDevice[],
  query: string,
): AudioDevice[] {
  const needle = query.trim().toLowerCase();
  if (needle.length === 0) return devices;
  return devices.filter(
    (device) =>
      device.name.toLowerCase().includes(needle) ||
      device.displayName.toLowerCase().includes(needle),
  );
}
