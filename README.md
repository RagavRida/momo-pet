# Momo — a tiny macOS desktop pet

Momo is a little creature that lives on your screen. It wanders, blinks,
follows your cursor, and naps when you leave it alone.

Built with Swift + AppKit + SceneKit. No model files — Momo is drawn from
procedural primitives, so the whole app is a single small binary.

<!-- Drop a GIF/screenshot of Momo in action here once you have one:
![Momo demo](docs/momo.gif)
-->

## Features

- **Idle** — gentle breathing, occasional blinks
- **Eye-tracking** — pupils follow your cursor
- **Wander** — walks to a new spot on screen every ~30s
- **Click react** — hop + squish + wide eyes
- **Drag** — grab and toss; squishes on landing
- **Sleep** — after 5 min of no interaction, sits down + closes eyes
- **Wake** — cursor near = wakes up
- **Speech bubble** — occasional thought
- **Edge aware** — turns around at screen edges

## Install

### Option A — Run from source (recommended for now)

Requires Xcode command-line tools (`xcode-select --install`).

```bash
git clone https://github.com/RagavRida/momo-pet.git
cd momo-pet
swift run
```

Quit from the menu bar — look for the small lavender dot.

### Option B — Download the `.app` from Releases

1. Grab `MomoPet.app.zip` from the
   [latest release](https://github.com/RagavRida/momo-pet/releases).
2. Unzip and drop `MomoPet.app` in `/Applications`.
3. **First launch:** right-click `MomoPet.app` → **Open** → click **Open**
   in the dialog.

   macOS shows a scary warning because the app isn't signed with an Apple
   Developer ID yet. Right-click → Open bypasses this safely. You only need
   to do it once.

   *(Signed builds are on the roadmap — see [Support](#support) below if
   you'd like to help fund that.)*

## Tech

- Swift + AppKit — transparent, borderless `NSWindow` that floats above
  every other window
- SceneKit — 3D scene built from procedural primitives (no `.usdz` /
  `.scn` assets required)

## Support

Momo is free and open source. If it makes you smile, you can say thanks:

- **UPI (India):** ragavrida@okicici
- **Ko-fi:** https://ko-fi.com/RagavRida
- **GitHub Sponsors:** the "Sponsor" button at the top of this repo

Funding goal: ₹8,500 to cover an Apple Developer account so everyone gets
a signed, one-click-install build.

## Contributing

Issues and PRs welcome. Good first contributions:

- New idle animations or reactions
- Extra pet skins / color variants
- Sound effects (opt-in)
- Multi-monitor polish

Please open an issue before large changes so we can align on direction.

## License

MIT — see [LICENSE](LICENSE).
