# VoiceInput Audio Switcher

List macOS audio input devices and switch the system default from Raycast.

Requires the **VoiceInput** companion app (CLI helper). Install it first:

```bash
curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash
# or
brew install kingxuchen/tap/voiceinput
```

The extension reads the device list on every launch and on `⌘R` — never from a cache.
