/** 安装命令文本冻结于 .issues/0020-store-publish-distribution-decision.md。 */

export const INSTALL_COMMAND =
  "curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash";

export const BREW_COMMAND = "brew install kingxuchen/tap/voiceinput";

export const INSTALLATION_GUIDE =
  "https://github.com/kingxuchen/voice-input#install";

/** 脚本地址钉 main，脚本内部再取最新 release，所以这段文本不随版本变。 */
export const SOUND_SETTINGS_URL =
  "x-apple.systempreferences:com.apple.Sound-Settings.extension";

export const VOICEINPUT_APP_PATH = "/Applications/VoiceInput.app";
