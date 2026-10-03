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

## Notifications from the bar (1.3)

With `notifications: true` the island takes over Omarchy's notification service (it disables `omarchy.notifications`, leaves a marker, and hands it back when the setting goes off or the plugin is removed). It keeps Omarchy's contract: the `notifications` IPC target (`dismissOne`, `dismissAll`, `invokeLast`, `showHistory`, `toggleDnd`, …), the DND state file and its exceptions (`omarchy-action` toasts and critical `notify-send`), `--exec` click commands, `replaces_id` updates in place.

In the bar, notifications roll out of the bar's bottom edge right under the island, as one column:

- **Normal**: exactly one open card (app name, summary, body, the sender's action buttons). Others wait under it as title rows (two, then `+N`) and move up when the open card leaves. Stand time 8 s (a sender's longer timeout up to 30 s), 4 s while others wait; the pointer on the column holds it. Click opens (default action / `--exec` / focus the app), right click or the close gadget dismisses, a waiting row clicked comes to the front.
- **Critical**: a requester (the sender's actions, **Later**, **Dismiss**) that pauses the open card until it is handled; Later puts it into the inbox.
- **Low** without buttons: no card, a still line in the island for 3.5 s, then the inbox.
- **Bell** beside the clock: unread count; left click opens the inbox (Mark read, Clear all, do-not-disturb switch), right click toggles do not disturb (bell sleeps, `DND` and a silent count).
- A 2 px line in the app's tone under the clock while a card hangs; it arrives as a short copper run.

Settings: `noteStyle` `workbench` (window head, Omarchy frame) or `bubble` (speech bubble whose notch flows out of the bar), `noteTopaz` (card heads, INBOX and the count in the Topaz pixel font; `false` uses the theme font). Motion is mechanical (constant speed, hard stop); with Omarchy's Reduced Motion the same moments fade instead.

IPC (`amiga-island`): `set noteStyle workbench|bubble`, `set noteTopaz true|false`, `set notifications true|false`; `note open|dismiss|later|next|action:<id>` (the column's buttons, for keybinds); `markRead`; `noteDemo mail|chat|phone|low|critical|actions|burst|story|many` (samples through the real queue).

Notifications appear on the focused monitor, under the island of that monitor's bar. Live banners are not kept over a shell restart (the inbox is).

**Theme material** (the Amiga Bar's `edge theme`, for themes that ship `bar-material.json` such as Tusche & Papier; the island reads the file from the current theme and follows theme switches): notes and the island popup take the theme's card instead of `noteStyle` — the theme's frame with its hard ink shadow (Papier) or halo (Tusche, Lavur), soft controls, no title bar, the theme font; a critical note keeps its text and frame in the theme's colours and carries one narrow signal stripe on its left edge and the signal on its symbol. With a Lavur theme (material `card.bloom`) the notes bloom instead: the fog's drop-and-grow out of the bar, every note its own sheet of wet paper (`views/InkSheet.qml`, the Amiga Bar's component and shaders) – ink fills it, the water clears it from its top and the residue evaporates with the water, then the pigment dries into a rim at the calm edge, gathered in short denser sections with a broken faint drying line further in (theme values `card.rest`); the sheets never melt into each other; a critical one carries a single brushed signal stroke inside the bloom. The fog look replaces it while on.

**Fog look** (the Amiga Bar's `fog` option, a test; the island follows it from `shell.json`): cards are blobs of the bar's colour in one gooey fog layer (`views/FogLayer.qml`). A drop falls out of the bar under the island, swells into the card, the text fades in; waiting rows hang under it as smaller blobs; going back, the text fades, the blob shrinks to a drop and is pulled into the bar, leaving a faint fog for a moment. The island popup grows out of the bar the same way (`views/FogPanel.qml` inside its `KeyboardPanel`). With the Amiga Bar's A500 form the fog takes the case's darker front colour, and the island writes `~/.local/state/omarchy/amiga-island/bar-span.json` (its span per bar, whether a note is out and on which monitor) for the drive slot and the DF0 LED.

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

Notification takeover (see above) and the OSD takeover are **opt-in**. `style`, `background`, notch sizes and `glow` are not offered in this variant; it always uses its flat theme-native rectangular surface. Round recording dots and progress gauges remain semantic indicators, not decorative capsules.

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
