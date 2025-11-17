# ✨ `Astereon.nvim`

Astereon is a Neovim plugin for Markdown knowledge bases in the spirit of “second brain” tooling. It lets you insert links, create notes from templates, manage media files, open daily pages, and perform safe renames that update every reference. Everything operates relative to the current `:pwd` and falls back to `vim.ui.select` unless you enable the optional [snacks.nvim](https://github.com/folke/snacks.nvim) pickers.

### 🌟 Why “Astereon”?

The name blends **aster** (star) with **eon** (an almost eternal span of time). Think of your note map as something meant to last for eons: stable IDs, links that never break, and a consistent structure even as the vault grows without limits.

## ⚙️ Key Features

- Scans every Markdown note under the working directory, respects ignored folders, and caches an index for fast lookups.
- Inserts links to notes or media files with configurable labels (automatic, title, filename, etc.).
- Guided creation of new notes with Lua templates, preferred directories, and automatic opening in the desired window.
- Selection flows for opening notes, narrowing results to a folder, or linking immediately after creating a note.
- Media file helpers (images, audio, video, PDF, etc.) to insert `[]()` or `![]()` with optional alt prompts and open the files inside Neovim.
- Daily notes with their own folder, template hook, and commands to move forward/backward in time.
- Safe rename flow: renames the current file and rewrites every relative link (`[]()`, `![]()`, `[ref]: url`) and even the link/alt text when desired.
- Quick action to regenerate the YAML frontmatter `id` using a customizable format.
- Optional snacks.nvim integration for numbered pickers with previews.
- Automatic index refresh on saves or directory changes.

## 📋 Requirements

- Neovim 0.9+ (LuaJIT).
- Optional: [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) if you want its UI; otherwise `vim.ui.select/input` is used.

## 📦 Installation

Example lazy spec (trimmed to the essentials—see the configuration section below for the full option set):

```lua
return {
  {
    "alchrdev/astereon.nvim",
    dependencies = { "folke/snacks.nvim" }, -- optional
    opts = {
      set_default_keymaps = true,
      open_new_note = false,
      rename = { update_link_text = "filename" },
      daily = { enable = true, folder = "apsn/dly" },
      snacks = {
        enable = true,
        preset = "vscode",
        show_index_numbers = false,
      },
      display = {
        search_link        = "filename",
        folder_search_link = "label+path",
        open_pick          = "filename",
        open_folder_pick   = "label+path",
      },
      media = {
        embed_images = true,
        prompt_alt_for_images = true,
      },
    },
  },
}
```

## 🚀 Quick Start

1. `:cd` or `:lcd` into the vault you want to work with (Astereon indexes everything under `vim.fn.getcwd()`).
2. Call `require("astereon").setup({ ... })` during startup with the options you want.
3. Run `:AstereonNewNote` to create something new, `:AstereonOpen` to jump to an existing note, or `:AstereonRename` to safely rename the current file.

From here you can wire the Lua functions into your own mappings or use the built-in ones.

### 🧭 Commands & Keymaps

| Command | What it does |
| --- | --- |
| `:InsertMdLink [auto\|title\|basename]` | Search notes and insert a Markdown link honoring `label_mode`. |
| `:AstereonNewNote` | Create a note from your template, asking where to store it. |
| `:AstereonOpen` / `:AstereonOpenFolder` | Open a note (optionally filter by folder first). |
| `:AstereonRename` | Rename the current file and patch every relative reference. |
| `:AstereonRefreshIndex` | Re-scan the vault when you make external changes. |
| `:AstereonUpdateId` | Reroll the YAML `id` in the current buffer. |
| `:AstereonDailyToday`, `:AstereonDailyNext`, `:AstereonDailyPrev` | Create/open daily notes (only when `daily.enable = true`). |

Lua helpers mirror these commands, so custom mappings look like:

```lua
local astereon = require("astereon")

vim.keymap.set("n", "<leader>nl", astereon.search_link, { desc = "Insert note link" })
vim.keymap.set("n", "<leader>no", astereon.open_pick,    { desc = "Open note" })
vim.keymap.set("n", "<leader>nn", function()
  astereon.create_note({ open_mode = "edit" })
end, { desc = "New note" })
vim.keymap.set("n", "<leader>mi", astereon.search_media_link, { desc = "Insert media file" })
vim.keymap.set("n", "<leader>rf", astereon.rename_current_file, { desc = "Rename current file" })
```

Set `set_default_keymaps = true` if you want Astereon to register a ready-made `<leader>` layer:

| Mapping | Action |
| --- | --- |
| `<leader>nn` | Create note |
| `<leader>nL` | Create note + insert link |
| `<leader>nl` / `<leader>nf` | Insert note link / folder-scoped link |
| `<leader>no` / `<leader>nF` | Open note / open note filtered by folder |
| `<leader>mi` / `<leader>mo` | Insert media link / open media file |
| `<leader>rf` | Rename current file |
| `<leader>uy` | Regenerate YAML ID |
| (daily mappings) | Configurable via `daily.mappings` |

### 🔁 Available Flows

- **Quick linking**: `astereon.search_link()` displays a label-sorted picker; `folder_search_link()` narrows to a folder, and `create_and_link()` spawns a new note then inserts its link immediately.
- **Opening**: `open_pick()` and `open_folder_pick()` open notes and honor `open_pick_mode = "edit"|"split"|"vsplit"`.
- **Media files**: `search_media_link()` inserts `[]()` or `![]()` based on extension (configurable list); `open_media_pick()` opens the file in Neovim for editing or preview.
- **Daily notes**: `open_daily_today/next/prev` create or open files inside `daily.folder`. The default heading is generated in Spanish, and you can override the body with `daily.template(date, heading)`.
- **Safe rename**: `rename_current_file()` prompts for the new name (keeps the extension) and updates every relative Markdown link in the vault, including reference-style links and `![]()` if `rename.include_images` is enabled.
- **Metadata**: `update_note_id()` ensures a unique YAML `id` based on `ids.format` (defaults to `%Y%m%d%H%M%S`).

## 🍿 Snacks Integration

When `snacks.enable = true` and `snacks.nvim` is installed, all selectors use `Snacks.picker`. You can tweak:

- `snacks.preset`, `snacks.layout`, and `snacks.show_index_numbers` for the global behavior.
- `display.snacks` to control preview/layout for note pickers (`search_link`, `open_pick`, etc.).
- `media.snacks` to enable previews for media file pickers.

If `snacks.enable = false`, the plugin falls back to `vim.ui.select`/`vim.ui.input` for maximum compatibility.

## 🛠️ Configuration

Every option ships with sensible defaults in `lua/astereon/init.lua`. Full example:

```lua
require("astereon").setup({
  label_mode = "auto",             -- how to label notes inside selectors
  scan_limit = 5000,               -- max files to index per root
  ignore_dirs = { ".git", ".obsidian", "node_modules" },

  new_note_preferred_dirs = { "areas", "projects" },
  new_note_template = function(title, slug, id)
    return string.format([[---
id: %s
title: "%s"
---

# %s

]], id, title, title)
  end,
  open_new_note = "edit",          -- open a note after creation: false|"edit"|"split"|"vsplit"

  open_pick_mode = "edit",         -- how to open notes selected from pickers

  display = {
    search_link        = "filename",     -- also accepts "label", "path", or combos
    folder_search_link = "label+path",
    open_pick          = "filename",
    open_folder_pick   = "label+path",
    snacks = {                          -- overrides for note pickers
      preview = false,
      preset = "vscode",
      layout = nil,
      show_index_numbers = true,
    },
  },

  ids = {
    format = "%Y%m%d%H%M%S",        -- passed to os.date
  },

  daily = {
    enable = true,
    folder = "journal/daily",
    template = function(date, heading)
      return table.concat({ "---", "mood:", "---", "", heading, "" }, "\n")
    end,
    mappings = {
      today = "<leader>ot",
      next  = "<leader>on",
      prev  = "<leader>op",
    },
  },

  media = {
    exts = { ".png", ".jpg", ".mp4", ".pdf" }, -- extend as needed
    image_exts = { ".png", ".jpg", ".jpeg", ".gif" },
    display = "filename+path",
    embed_images = true,
    prompt_alt_for_images = true,
    snacks = {
      preview = true,
      preset = "vscode",
    },
  },

  rename = {
    include_images = true,
    update_reference_style = true,
    update_link_text = "auto",      -- "keep"|"filename"|"title"
    update_image_alt = "auto",
    filename_label_style = "spaces",-- "slug"|"spaces"|"titlecase"
    auto_prefers = "title",         -- used when update_link_text = "auto"
  },

  snacks = {
    enable = true,
    preset = "vscode",
    show_index_numbers = true,
  },

  set_default_keymaps = false,      -- load built-in <leader> mappings if desired

  auto_refresh = {
    enable = true,
    events = { "BufWritePost", "BufFilePost", "DirChanged" },
  },
})
```

### 🗂️ Notes on the Index

- Paths are normalized and sorted; if you exceed `scan_limit`, the walk stops to avoid freezes.
- `ignore_dirs` compares each segment (`.git`, `.obsidian`, `node_modules`, etc.) to keep the walk inside your vault.
- `auto_refresh` only invalidates the cache when a Markdown file changes, keeping the feature lightweight.
- Call `require("astereon").refresh_index()` whenever you import files externally and need a manual refresh.

> Final thoughts: Astereon’s workflow takes many ideas from the linking ergonomics of Obsidian MD. I was able to develop—and ultimately finish—the plugin thanks to Ainë (ChatGPT Codex).
