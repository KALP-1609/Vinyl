# Vinyl

A tiny, glassy, always-on-top vinyl player for macOS that follows the **Spotify desktop app**.

- Floats above every app (even fullscreen ones) and remembers where you left it
- Click the **needle** to play / pause — the record spins with the current album art
- The window background blurs and tints itself from the album art
- Lyrics button slides the window open with **synced lyrics** (click a line to jump to it)
- Previous / next / seek, all controlling Spotify

Requires **macOS 14 (Sonoma) or newer** and the **Spotify desktop app** (not the web player). Works with Free and Premium.

Vinyl is an independent project and is not affiliated with, endorsed by, or sponsored by Spotify. “Spotify” is a trademark of Spotify AB.

## Install

1. Download `Vinyl-x.y.z.dmg` from the [Releases](../../releases) page.
2. Open it and drag **Vinyl** into **Applications**.
3. **First launch** — the app isn't notarized by Apple, so macOS will warn you the first time:
   - **macOS 14:** right-click (or Control-click) Vinyl → **Open** → **Open**.
   - **macOS 15 or newer:** double-click Vinyl, dismiss the warning, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to "Vinyl".
   - Or in Terminal: `xattr -dr com.apple.quarantine /Applications/Vinyl.app`
4. Start Spotify and play a song. macOS will ask *"Vinyl wants to control Spotify"* — click **OK**.

## Troubleshooting

| What you see | Fix |
|---|---|
| "Allow Vinyl to control Spotify" | Click **Open Settings**, then turn on **Spotify** under **Vinyl** in **Privacy & Security → Automation**. It reconnects on its own. |
| "Spotify isn't running" | Click **Open Spotify** (or just open it). Vinyl connects automatically, in any order. |
| "Spotify isn't installed" | Install the desktop app from spotify.com/download. |
| No lyrics | Lyrics come from [lrclib.net](https://lrclib.net); not every song is there, and you need internet. Ads and podcasts have none. |
| Window is off-screen | Quit and reopen Vinyl — it recenters itself if its saved screen is gone. |
| Asked for permission again after an update | Updates are ad-hoc signed, so macOS treats each version as a new app. Allow it again. |

Privacy: the only data sent anywhere is the song title, artist and length, to lrclib.net, to find lyrics. Cover art is loaded from Spotify's image servers.

## Build from source

Requires Xcode (or the Command Line Tools) on macOS 14+.

```bash
git clone <https://github.com/KALP-1609/Vinyl>
cd Vinyl
bash scripts/build_app.sh 1.0.0       # creates dist/Vinyl.app, .zip and .dmg
open dist/Vinyl.app
```

## License

MIT
