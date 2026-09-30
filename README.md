# Amiga Island for Omarchy

Local theme-native adaptation of [Arjun010011/omarchy-dynamic-island](https://github.com/Arjun010011/omarchy-dynamic-island), based on commit `9d6e3f4e072a77b7b11086934b785b6d7f2518f7`. Original MIT license retained.

## Appearance

- Flat Omarchy popup colors and native `BorderSurface` frame (including the theme border gradient).
- Compact rectangular surfaces and controls, theme monospace font, segmented status rail.
- Short non-overshooting transitions; no glass blur, cover wash, hardware notch or pill/disc styling.
- Live colors, font scale and Reduced Motion follow the running Omarchy shell.

## In the bar (1.2)

The plugin is both a `panel` (state and sources) and a `bar-widget`. Put `nerdibeard.amiga-island` in the bar (it replaces the clock; make it `bar.centerAnchor`) and the island lives there:

- At rest the widget is the clock (`format`, default `HH:mm`).
- Anything live grows a tinted segment beside the time: working agents, timer/stopwatch (with a progress rule), music, a meeting about to start, recording, mic/camera; announcements (agent done, limits, track change, charging) take the segment for a few seconds.
- Left click opens the island as a **native bar popup** (Omarchy card, border, gap and outside-click/Esc dismissal, and it closes when another bar popup opens). Right click opens the calendar, middle click plays/pauses.
- The floating strip below the bar is not mapped while a bar widget is mounted. Without the widget in the bar (and with a `plugins[]` entry instead) the old floating island comes back. `barMode: false` forces that.

Settings live in the bar entry: while the plugin is in the bar, the shell reads and writes its entry in `bar.layout`, so keep only that one entry (no second one in `plugins[]`).

## Desktop integration (1.1)

The island shows what the rest of this desktop already knows instead of keeping its own copy. All links are **read-only**; nothing is written to or sent from them.

| Source | Shown as | Setting |
|---|---|---|
| OmaMail calendar cache `~/.cache/omamail/calendar-bar.json` (iCloud/CalDAV, same as the bar clock) | next meeting, month view, "starting now" toast | `omamail` |
| Flux daemon socket `$XDG_RUNTIME_DIR/flux/fluxd.sock` (`subscribe` only) | working herdr/OpenClaw agents as a live activity; "Done" toast after ≥20 s of work | `flux`, `agents`, `agentDone` |
| Flux paired phone | battery in the opened island; one low-battery HUD per discharge | `phone` |
| Omarchy agent usage `~/.local/state/omarchy/agents/usage/<id>.json` | HUD when a limit crosses 90 %, reaches 100 % or resets; tightest limit in the opened island | `aiLimits`, `aiProviders` |

Extra `.ics` feeds still work (`calendars`, or **+** in the calendar view).

**Resting state** (`idle`): `auto` (default) shows the resting island only when it has something the bar does not already show (working agents, a meeting within 12 h, a limit ≥ 90 %, low phone/laptop battery, today's all-day events, Do Not Disturb), otherwise an 8 px lip under the bar that opens on hover/click. `pill` always shows it; `hidden` shows nothing until something is live. The time and date stay in the bar.

The gap under the bar defaults to Omarchy's own popup gap (`Style.gapsOut`); set `topMargin` to override.

## Integration

Plugin ID: `nerdibeard.amiga-island`. IPC: `amiga-island`.

This is an additional panel, **not a bar replacement**. By default it floats below the existing top bar and reserves no extra space. `topMargin` (optional) is the gap **below** that bar, not the absolute distance to the display edge; the compositor places the zero-exclusive-zone surface below existing reserved panels. The default `top` layer leaves fullscreen apps above it. Only the island and the second-activity tile take pointer input.

Existing Omarchy notifications, OSD and keybindings are untouched by default. Corresponding settings are `notifications: false`, `osd: false`, `keybind: false`, `volume: false`, `brightness: false`. Calendar subscriptions start empty; external holiday feeds are off. No account settings are imported.

Source retains optional notification/OSD takeover features from upstream. They are **opt-in**, not part of this installation. `style`, `background`, notch sizes and `glow` are not offered in this variant; it always uses its flat theme-native rectangular surface. Round recording dots and progress gauges remain semantic indicators, not decorative capsules.

## Install / develop

Run `OMARCHY_PATH=/path/to/omarchy ./dev-install.sh`, then `omarchy-shell shell rescanPlugins` and `omarchy plugin enable nerdibeard.amiga-island` in the desktop environment. The script installs only this plugin directory. Local edits are kept in this repository, separate from upstream updates.

Useful IPC calls:

```sh
omarchy-shell amiga-island state
omarchy-shell amiga-island demo media
omarchy-shell amiga-island expand
omarchy-shell amiga-island demo off
omarchy-shell amiga-island timer 5m "Focus"
omarchy-shell amiga-island timerCancel
```

To disable only this panel: `omarchy plugin disable nerdibeard.amiga-island`. Do not restore an old whole `shell.json` over newer unrelated settings.

See `UPSTREAM.md` for the original activity and scripting documentation; replace the original plugin ID and `dynamic-island` IPC target with the names above. Apple styling and takeover defaults described there do not apply to this local variant.
