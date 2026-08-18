# Easy Kanban

Local Kanban boards from the Omarchy bar. Multiple boards, columns, drag-and-drop tickets, and deadline reminders — all stored on disk, no network.

## Install

```bash
omarchy plugin add https://github.com/ypMrg/omarchy-easy-kanban.git --enable
```

## Update / Remove

Plugin id: `io.github.ypmrg.omarchy-easy-kanban`

```bash
omarchy plugin update io.github.ypmrg.omarchy-easy-kanban
omarchy plugin remove io.github.ypmrg.omarchy-easy-kanban
```

## Default board

On first run (or after a corrupt data file is recovered), one board is created:

| Board    | Columns                                      |
| -------- | -------------------------------------------- |
| Personal | **Todo**, **In Progress**, **Done** (empty) |

New boards get the same three default columns (new ids, empty tickets).

## Data path

Boards are saved locally to:

```text
~/.local/state/omarchy/easy-kanban.json
```

There is no cloud sync. A bad file is copied to `easy-kanban.json.bak` and replaced with a clean default on the next save.

## Hover recap

The bar shows only the Easy Kanban icon. Hover the icon (with the panel closed) for a short recap of the **active** board: column names with ticket counts, plus an overdue count (tickets past their deadline, excluding **Done** columns).

## Drag and keyboard

Click the bar icon to open the board panel. Drag a card to move it between columns or reorder within a column. Click a card to focus it (accent ring), then use keys:

| Key              | Action                                                      |
| ---------------- | ----------------------------------------------------------- |
| `Esc`            | Close the open dialog, or the panel if none                 |
| `N`              | New ticket in the focused card’s column (first if none)     |
| `Shift` + arrows | Move focus to another card (skips empty columns)            |
| `H` / Left       | Move focused card one column left                           |
| `L` / Right      | Move focused card one column right                          |
| `J` / Down       | Move focused card down in its column                        |
| `K` / Up         | Move focused card up in its column                          |

Keys at the edge of a board or column are no-ops. Move keys are ignored while a dialog or text field is open.

## Deadlines and reminders

Tickets may have an optional deadline (`YYYY-MM-DD`). Cards show **Due today** or **Overdue** badges.

The bar widget watches deadlines while it is loaded:

- On load, every 60 seconds, and when the local calendar day rolls over
- Tickets in columns named **Done** (case-insensitive) are skipped
- Each ticket is notified at most once per local day
- At most 5 notifications per tick; the rest wait for the next tick

Reminders require the **widget to stay on the bar**. If you remove the widget from the bar, the watcher is not running and no deadline notifications are sent.

## Requirements

- [Omarchy](https://omarchy.org) **Quattro** (or newer with the plugin system)
- Bar widget support and desktop notifications (`omarchy-notification-send`)

## License

[MIT](LICENSE) — Copyright (c) 2026 Matthieu G.C.
