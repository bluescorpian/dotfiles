# keys_cheatsheet

A local keybindings viewer. Add a JSON file per app, open the HTML in a browser.

## Start it

```bash
python3 -m http.server 8787 -d /home/shared/dotfiles/keys_cheatsheet &
# then open http://localhost:8787
```

Or add a shell alias:

```bash
alias keys="python3 -m http.server 8787 -d /home/shared/dotfiles/keys_cheatsheet &>/dev/null & sleep 0.3 && xdg-open http://localhost:8787"
```

## Add a new source

**1. Create the JSON file** (copy `sway.json` as a template):

```json
{
  "meta": {
    "title": "My App Keybindings",
    "host": "laptop",
    "layout_note": "Optional note shown in the info bar.",
    "generated": "2026-05-11"
  },
  "groups": [
    {
      "id": "navigation",
      "label": "Navigation",
      "color": "#89b4fa",
      "bindings": [
        { "keys": ["Ctrl", "t"],     "action": "New tab" },
        { "keys": ["Ctrl", "w"],     "action": "Close tab" },
        { "keys": ["Ctrl", "Tab"],   "action": "Next tab",  "note": "optional detail" }
      ]
    }
  ]
}
```

**2. Register it in `sources.json`:**

```json
{
  "default": "sway",
  "sources": [
    { "id": "sway",  "label": "Sway",   "icon": "🪟", "color": "#89b4fa", "file": "sway.json" },
    { "id": "myapp", "label": "My App", "icon": "🐱", "color": "#a6e3a1", "file": "myapp.json" }
  ]
}
```

Reload the browser. The new tab appears immediately.

## JSON schema reference

### `sources.json`

| Field | Type | Description |
|-------|------|-------------|
| `default` | string | Source `id` to activate on first load |
| `sources[].id` | string | Stable identifier, used in URL hash (`#myapp`) |
| `sources[].label` | string | Tab display name |
| `sources[].icon` | string | Emoji shown in the tab |
| `sources[].color` | string | Hex accent color for the tab and source badge |
| `sources[].file` | string | Path to the source JSON file (relative to this directory) |

### Per-source JSON

| Field | Type | Description |
|-------|------|-------------|
| `meta.title` | string | Full title (shown in browser tab / info bar) |
| `meta.host` | string | Optional host label shown in info bar |
| `meta.modifier_display` | string | e.g. `"Super"` — shown in info bar |
| `meta.modifier_xkb` | string | e.g. `"Mod4"` — shown in info bar |
| `meta.layout_note` | string | Freeform note shown in info bar |
| `meta.generated` | string | Date string (informational only) |
| `groups[].id` | string | Category identifier for filter chips |
| `groups[].label` | string | Category display name |
| `groups[].color` | string | Hex accent color for the card |
| `groups[].bindings[].keys` | string[] | Key parts — each element becomes a `<kbd>` badge |
| `groups[].bindings[].action` | string | Human-readable description (searchable) |
| `groups[].bindings[].note` | string? | Optional small detail shown below the action |

### Tips for `keys` values

- Use display-friendly strings: `"Super"`, `"Shift"`, `"Ctrl"`, `"Alt"`, `"←"`, `"↑"`, `"↓"`, `"→"`
- For media/fn keys use descriptive labels: `"🔊 Vol+"`, `"☀ Bright+"`, `"⏯ Play/Pause"`
- For slash commands, put the whole command as the single key: `["/help"]`
- Use ranges for repetitive bindings: `["Super", "1–10"]`
