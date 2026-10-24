import {
  Action,
  ActionPanel,
  Icon,
  List,
  Toast,
  openExtensionPreferences,
  showHUD,
  showToast,
  Keyboard,
} from "@raycast/api";
import { useCallback, useEffect, useRef, useState } from "react";

import { listDevices, preferenceCliPath, setDefault } from "./lib/cli";
import { systemLocale } from "./lib/locale";
import {
  BREW_COMMAND,
  INSTALLATION_GUIDE,
  INSTALL_COMMAND,
  SOUND_SETTINGS_URL,
  VOICEINPUT_APP_PATH,
} from "./lib/constants";
import { switchFeedback } from "./lib/feedback";
import { filterDevices } from "./lib/filter";
import { stringsFor, type Strings } from "./lib/i18n";
import type { AudioDevice, CliResult, DeviceListResponse } from "./lib/types";

type State =
  | { kind: "loading" }
  | { kind: "ready"; devices: AudioDevice[] }
  | { kind: "missing" }
  | { kind: "timeout" }
  | { kind: "outdated"; direction: "app" | "plugin" }
  | { kind: "failed" };

/** CLI 结果 → 界面状态。缺 CLI 走安装空态，不是错误页。 */
function toState(result: CliResult<DeviceListResponse>): State {
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

export default function SwitchInput() {
  const [locale, setLocale] = useState<string | undefined>(undefined);
  const t = stringsFor(locale);
  const cliPath = preferenceCliPath();
  const [state, setState] = useState<State>({ kind: "loading" });
  // Raycast 会把根搜索的查询词带进命令的搜索框（真机实证：输入 "switch audio" 回车进入后，
  // 该查询词会经 onSearchTextChange 推给命令，把设备列表过滤成 No Results）。
  // 受控空串盖不住它，因此丢弃挂载瞬间那一次推送；之后的输入都是用户真实输入。
  const [searchText, setSearchText] = useState("");
  const mountedAt = useRef(Date.now());

  const handleSearchTextChange = useCallback((value: string) => {
    const isCarriedFromRootSearch = Date.now() - mountedAt.current < 400;
    if (isCarriedFromRootSearch) return;
    setSearchText(value);
  }, []);

  const load = useCallback(async () => {
    setState({ kind: "loading" });
    setState(toState(await listDevices(cliPath)));
  }, [cliPath]);

  useEffect(() => {
    void systemLocale().then(setLocale);
    void load();
  }, [load]);

  // 加载中不渲染空态：否则真实数据回来前会闪一次 EmptyView。
  const isLoading = state.kind === "loading";
  const allDevices = state.kind === "ready" ? state.devices : [];
  // `onSearchTextChange` 一存在，Raycast 的 `filtering` 默认就是 false；
  // 内建过滤又会被根搜索带进来的查询词污染，所以过滤由自己接管（见 lib/filter.ts）。
  const devices = filterDevices(allDevices, searchText);

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder={t.switchToThisInput}
      searchText={searchText}
      onSearchTextChange={handleSearchTextChange}
      filtering={false}
    >
      {!isLoading && state.kind !== "ready" && (
        <ErrorView state={state} t={t} onRetry={load} cliPath={cliPath} />
      )}
      {/* 真的没有设备（HAL 枚举不出输入流） */}
      {!isLoading && state.kind === "ready" && allDevices.length === 0 && (
        <List.EmptyView
          icon={Icon.Microphone}
          title={t.cannotReadDevices}
          actions={
            <ActionPanel>
              <Action
                title={t.retry}
                icon={Icon.ArrowClockwise}
                onAction={load}
              />
            </ActionPanel>
          }
        />
      )}
      {/* 有设备但搜不到：给清空搜索的出口，别让人以为设备消失了 */}
      {!isLoading &&
        state.kind === "ready" &&
        allDevices.length > 0 &&
        devices.length === 0 && (
          <List.EmptyView
            icon={Icon.MagnifyingGlass}
            title={t.noMatches}
            description={searchText}
            actions={
              <ActionPanel>
                <Action
                  title={t.clearSearch}
                  icon={Icon.XMarkCircle}
                  onAction={() => setSearchText("")}
                />
                <Action
                  title={t.retry}
                  icon={Icon.ArrowClockwise}
                  onAction={load}
                />
              </ActionPanel>
            }
          />
        )}
      {devices.map((device) => (
        <List.Item
          key={device.id}
          icon={Icon.Microphone}
          title={device.displayName}
          accessories={
            device.isDefault ? [{ tag: t.current, icon: Icon.CheckCircle }] : []
          }
          actions={
            <ActionPanel>
              <Action
                title={t.switchToThisInput}
                icon={Icon.CheckCircle}
                onAction={() =>
                  void switchTo(device, cliPath, t, setState, load)
                }
              />
              <Action
                title={t.refresh}
                icon={Icon.ArrowClockwise}
                onAction={load}
                shortcut={Keyboard.Shortcut.Common.Refresh}
              />
              <Action.CopyToClipboard
                title={t.copyDeviceName}
                content={device.displayName}
                shortcut={{ modifiers: ["cmd"], key: "c" }}
              />
              <Action.Open
                title={t.openVoiceInput}
                target={VOICEINPUT_APP_PATH}
                shortcut={{ modifiers: ["cmd", "shift"], key: "v" }}
              />
              <Action.Open
                title={t.openSoundSettings}
                target={SOUND_SETTINGS_URL}
                shortcut={Keyboard.Shortcut.Common.OpenWith}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

async function switchTo(
  device: AudioDevice,
  cliPath: string | undefined,
  t: Strings,
  setState: (state: State) => void,
  reload: () => Promise<void>,
) {
  const feedback = switchFeedback(
    await setDefault(device.id, cliPath),
    device,
    t,
  );

  if (feedback.kind === "ok") {
    setState({ kind: "ready", devices: feedback.devices });
    // HUD 会自动关闭主窗口：切换成功就是要离开。
    await showHUD(feedback.message);
    return;
  }

  if (feedback.kind === "reload") {
    // 设备在切换瞬间消失：重读而不是留下一个说谎的列表。窗口保持打开，方便直接重选。
    await reload();
  }
  await showToast({ style: Toast.Style.Failure, title: feedback.message });
}

function ErrorView(props: {
  state: Extract<
    State,
    { kind: "missing" | "timeout" | "outdated" | "failed" }
  >;
  t: Strings;
  onRetry: () => Promise<void>;
  cliPath?: string;
}) {
  const { state, t, onRetry } = props;
  const retryAction = (
    <Action title={t.retry} icon={Icon.ArrowClockwise} onAction={onRetry} />
  );

  if (state.kind === "missing") {
    return (
      <List.EmptyView
        icon={Icon.Download}
        title={t.emptyTitle}
        description={t.emptyDescription}
        actions={
          <ActionPanel>
            <Action.CopyToClipboard
              title={t.copyInstallCommand}
              content={INSTALL_COMMAND}
            />
            <Action.CopyToClipboard
              title="Copy Homebrew Command"
              content={BREW_COMMAND}
            />
            <Action.OpenInBrowser
              title={t.openInstallationGuide}
              url={INSTALLATION_GUIDE}
            />
            {retryAction}
            <Action
              title={t.openPreferences}
              icon={Icon.Gear}
              onAction={openExtensionPreferences}
            />
          </ActionPanel>
        }
      />
    );
  }

  // 「App 太旧」要用户升级伴侣 App；「插件太旧」只能更新扩展——两者动作不同，文案不能混。
  const title =
    state.kind === "timeout"
      ? t.timedOut
      : state.kind === "outdated"
        ? state.direction === "plugin"
          ? t.pluginOutdated
          : t.outdated
        : t.cannotReadDevices;

  return (
    <List.EmptyView
      icon={state.kind === "outdated" ? Icon.ExclamationMark : Icon.Warning}
      title={title}
      actions={
        <ActionPanel>
          {retryAction}
          {state.kind === "outdated" && state.direction === "app" && (
            <Action.CopyToClipboard
              title={t.copyInstallCommand}
              content={INSTALL_COMMAND}
            />
          )}
          {state.kind === "outdated" && state.direction === "plugin" && (
            <Action
              title={t.updateExtension}
              icon={Icon.Download}
              onAction={openExtensionPreferences}
            />
          )}
          <Action
            title={t.openPreferences}
            icon={Icon.Gear}
            onAction={openExtensionPreferences}
          />
        </ActionPanel>
      }
    />
  );
}
