import {
  Action,
  ActionPanel,
  Icon,
  Keyboard,
  List,
  Toast,
  openExtensionPreferences,
  showHUD,
  showToast,
} from "@raycast/api";
import { useCallback, useEffect, useRef, useState } from "react";

import { listDevices, preferenceCliPath, setDefault } from "./lib/cli";
import { SOUND_SETTINGS_URL, VOICEINPUT_APP_PATH } from "./lib/constants";
import { switchFeedback } from "./lib/feedback";
import { filterDevices } from "./lib/filter";
import { stringsFor } from "./lib/i18n";
import { systemLocale } from "./lib/locale";
import {
  emptyStateFor,
  toState,
  type CommandIntent,
  type EmptyAction,
  type State,
} from "./lib/presentation";
import { shouldDropSearchText } from "./lib/searchText";
import type { AudioDevice } from "./lib/types";

export default function SwitchInput() {
  const [locale, setLocale] = useState<string | undefined>(undefined);
  const t = stringsFor(locale);
  const cliPath = preferenceCliPath();
  const [state, setState] = useState<State>({ kind: "loading" });
  const [searchText, setSearchText] = useState("");
  const mountedAt = useRef(Date.now());

  // 挂载瞬间那一次推送是根搜索词的回声，必须丢弃（判据见 lib/searchText.ts）。
  const handleSearchTextChange = useCallback((value: string) => {
    if (shouldDropSearchText(mountedAt.current, Date.now())) return;
    setSearchText(value);
  }, []);

  const load = useCallback(async () => {
    setState({ kind: "loading" });
    setState(toState(await listDevices(cliPath)));
  }, [cliPath]);

  const switchTo = useCallback(
    async (device: AudioDevice) => {
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

      // 设备在切换瞬间消失：重读而不是留下一个说谎的列表。窗口保持打开，方便直接重选。
      if (feedback.kind === "reload") await load();
      await showToast({ style: Toast.Style.Failure, title: feedback.message });
    },
    [cliPath, t, load],
  );

  useEffect(() => {
    void systemLocale().then(setLocale);
    void load();
  }, [load]);

  // `onSearchTextChange` 一存在，Raycast 的 `filtering` 默认就是 false；
  // 内建过滤又会被根搜索带进来的查询词污染，所以过滤由自己接管（见 lib/filter.ts）。
  const devices = filterDevices(
    state.kind === "ready" ? state.devices : [],
    searchText,
  );
  const empty = emptyStateFor(
    state,
    { visibleCount: devices.length, query: searchText },
    t,
  );

  // 空态里需要真实副作用的动作：判定层只交出意图，执行留在组件。
  const runCommand = useCallback(
    (intent: CommandIntent) => {
      switch (intent) {
        case "retry":
          void load();
          break;
        case "clearSearch":
          setSearchText("");
          break;
        case "preferences":
          void openExtensionPreferences();
          break;
      }
    },
    [load],
  );

  return (
    <List
      isLoading={state.kind === "loading"}
      searchBarPlaceholder={t.switchToThisInput}
      searchText={searchText}
      onSearchTextChange={handleSearchTextChange}
      filtering={false}
    >
      {empty && (
        <List.EmptyView
          icon={empty.icon}
          title={empty.title}
          description={empty.description}
          actions={
            <ActionPanel>
              {empty.actions.map((action, index) =>
                renderEmptyAction(action, index, runCommand),
              )}
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
                onAction={() => void switchTo(device)}
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

/**
 * 空态动作 → Action 组件。`copy` / `openUrl` 自带执行方式，其余按 intent 回派给组件，
 * 因此这份映射不需要知道 `load` / `setSearchText` 的存在。
 */
function renderEmptyAction(
  action: EmptyAction,
  key: number,
  run: (intent: CommandIntent) => void,
) {
  switch (action.intent) {
    case "copy":
      return (
        <Action.CopyToClipboard key={key} title={action.title} content={action.content} />
      );
    case "openUrl":
      return (
        <Action.OpenInBrowser key={key} title={action.title} url={action.url} />
      );
    default:
      return (
        <Action
          key={key}
          title={action.title}
          icon={action.icon}
          onAction={() => run(action.intent)}
        />
      );
  }
}
