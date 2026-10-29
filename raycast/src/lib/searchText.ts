/**
 * 查询词继承的修法（真机坑，见 0023）。Raycast 会把根搜索框里的词注入命令的搜索框：
 * 在根搜索敲「switch audio」回车进来，命令会收到一次 `onSearchTextChange("switch audio")`，
 * 设备列表就被过滤成 No Results。受控 `searchText=""`、`undefined` 初值都盖不住这次推送，
 * 唯一有效做法是丢弃挂载后极短窗口内的推送——之后到达的才是用户真实输入。
 *
 * 代价：挂载后 400 ms 内开始的真实输入也会被丢弃。此时列表通常还在等 CLI 返回，
 * 用户也还没看清内容，这是实测出来能同时兼顾两边的窗口（见 0023「两个真机坑」）。
 */
export const ROOT_SEARCH_GRACE_MS = 400;

/**
 * 这次搜索词推送该丢弃吗？`now - mountedAt` 为负（系统时钟被回拨）时同样丢弃：
 * 无法证明用户已经能输入，宁可少接受一次输入，也不放开污染。
 */
export function shouldDropSearchText(mountedAt: number, now: number): boolean {
  return now - mountedAt < ROOT_SEARCH_GRACE_MS;
}
