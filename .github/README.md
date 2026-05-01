<div align="center">
  <h1>ii-eve Hyprland Dots</h1>
  <p><i>Just a personal fork of <a href="https://github.com/vaguesyntax/ii-vynx">ii-vynx</a>, which is itself a fork of <a href="https://github.com/end-4/dots-hyprland">end-4/dots-hyprland</a>.</i></p>
</div>

<div align="center">

![](https://img.shields.io/github/last-commit/djOB2EOTWQW1/ii-eve?&style=for-the-badge&color=8ad7eb&logo=git&logoColor=D9E0EE&labelColor=1E202B)

</div>

<div align="center">
  <h2>• So what is this? •</h2>
</div>

I've been daily-driving illogical-impulse for a while, then moved to ii-vynx, and at some point I started piling up enough small tweaks of my own that it made sense to keep them in their own repo. So here we are - **ii-eve**.

Nothing revolutionary. Same Hyprland + Quickshell setup you already know, just with a few features I missed and a couple of things I wanted to work better.

<div align="center">
  <h2>• What's different from ii-vynx •</h2>
</div>

If you're already on ii-vynx (or end-4's dots), here's the short version of what you actually get on top:

### App Launcher

The big one. A full app launcher panel with:

- **Folders** - group apps however you want, with previews on the tile
- **Drag-and-drop reordering** - move apps inside folders or rearrange the main grid live, with proper shift animations
- **Selection mode** - multi-select apps for bulk actions
- **Vimium-style keyboard navigation** - hit a key, jump to an app, no mouse needed
- **Help overlay** - `Ctrl+/` shows you every shortcut available
- **GPU launching** - right-click → launch with dGPU or iGPU, or set a default
- **Renaming, context menus, empty-state hints** - basically everything you'd expect from a launcher that someone actually uses every day

This doesn't exist in ii-vynx or end-4's dots - it's the main reason this fork exists.

### Anime Booru - actually usable

The Booru module in upstream worked, but it had rough edges. Eve cleans them up:

- **API support added for Danbooru / Gelbooru** if you do want to log in (favorites, etc.)
- **New commands** - page limit, thumbnail/image switching, history (with deduplication), Gelbooru `pass_hash` for favorites
- **Unified provider auth UI** so you're not hunting for where each provider hides its settings
- **Settings button** for Gelbooru API / User ID / Pass Hash / provider switching, right where you'd expect it
- API key instructions banner so you know what each provider actually needs

### Smaller things

Reworked system tray from Elpo - cleaner and more polished look
- Trying to fix Quickshell warnings as I find them (it's an ongoing thing, not a one-shot cleanup)
- Various small QoL fixes scattered around

<div align="center">
  <h2>• Should you use this instead of ii-vynx? •</h2>
</div>

Honestly? **Use ii-vynx if you don't care about the App Launcher and don't use the Booru module much.** vaguesyntax keeps it well-maintained and that's a great baseline.

**Use ii-eve if:**
- You want a real app launcher with folders + drag-reorder, not just a dmenu-style search
- You actually use the anime booru and want it to behave properly (especially without API keys)
- You don't mind tracking a smaller, more personal fork

I keep this fork up to date with ii-vynx's changes, so you're not missing out on the upstream work either.

<div align="center">
     <h2>• screenshots •</h2>
</div>

| Just my picture | Overlay and AI sidebar |
| ----------- | ----------- |
| <img width="1918" height="1077" alt="image" src="https://github.com/user-attachments/assets/1e873857-995d-4cb8-af90-1cf3cfab7fa0" /> | <img width="1916" height="1078" alt="image" src="https://github.com/user-attachments/assets/53c3b4be-9ba0-40dc-8570-c6a3a80c18cf" /> |

| Media mode | Sharp style |
| ----------- | ----------- |
| <img width="1920" height="1077" alt="image" src="https://github.com/user-attachments/assets/a966c5ca-ef0a-4ecf-882b-e7ef55dde74e" /> | <img width="1918" height="1078" alt="image" src="https://github.com/user-attachments/assets/745aafcd-246e-4433-a81f-37a88ac5c1ee" /> |

<div align="center">
    <h2>• Heads up •</h2>
</div>

These dots are based on **illogical-impulse** ([end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)) by way of [ii-vynx](https://github.com/vaguesyntax/ii-vynx). Most credit belongs to those projects - I'm just adding flavor.

This is my daily driver, so it generally works. But it's still a personal fork, which means there will be bugs I haven't hit yet and changes I make because they suit *me*. Read the [Wiki](https://github.com/djOB2EOTWQW1/ii-eve/wiki) before installing so you know what you're signing up for.

For real bugs, please use [GitHub Issues](https://github.com/djOB2EOTWQW1/ii-eve/issues).

**P.S.** Before you say anything - this setup is just for me. Bug reports welcome, complaints not so much :d

<div align="center">
    <h2>• installation •</h2>
</div>

1. Clone the repo (with submodules):

```bash
git clone https://github.com/djOB2EOTWQW1/ii-eve.git --recurse-submodules
```

2. Run the setup script:

```bash
./setup-ii-eve.sh
```

All flags:

```bash
./setup-ii-eve.sh --help
```

<div align="center">
    <h2>• updating •</h2>
</div>

Three ways, pick whichever you like.

Re-run the setup script:

```bash
./setup-ii-eve.sh
```

Use the CLI (if installed):

```bash
eve update
```

Or just hit the update button in the shell:

<img width="445" height="202" alt="image" src="https://github.com/user-attachments/assets/d1420a5b-4d38-4bbe-9ee1-af71f01cd91d" />


<div align="center">
    <h2>• credits •</h2>
</div>

**[end-4](https://github.com/end-4)** Creator of illogical-impulse. None of this exists without them.

**[ii](https://github.com/end-4/dots-hyprland):** A perfect hyprland dots in material-3 style

**[vaguesyntax](https://github.com/vaguesyntax)** For ii-vynx, which is the actual base of this fork. Thanks for the foundation.

**[Quickshell](https://quickshell.org/)** The Qt-Quick widget system that makes all of this possible.

**[Hyprland](https://hypr.land/)** The (loves-to-crash) Wayland compositor underneath it all.