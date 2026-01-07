# 🌟 astereon.nvim

> **Markdown links, media management, and reference-aware renaming for Neovim.**

Astereon provides a workflow to handle internal links and media assets in Markdown files. It uses fuzzy finders to insert links or images and ensures referential integrity by updating links across the workspace when a file is renamed.

---

## 💭 Philosophy

**Why not just use Obsidian?**

I heavily use and enjoy Obsidian MD for reading and visualization. However, relying exclusively on WikiLinks (`[[Note]]`) can create **vendor lock-in**, breaking navigation outside of specific apps.

Astereon is designed to keep your notes **portable**. By automating the usage of **standard Markdown links** (`[Note](path/to/note.md)`), ensures your knowledge base remains navigable in any editor—whether it's Neovim, VSCode, or a GitHub web preview—without needing translation layers.

---

## ✨ Features

* **🔗 Link Insertion:** Search and insert links to other notes using fuzzy finders. Includes logic to automatically handle spacing around the link.
* **🖼️ Media Management:** Browse and embed images, audio, and video files with file-type icons (e.g., 🖼️, 🎥, 🎵) and previews (via `snacks.nvim`).
* **📂 Visual Scannability:** Configurable icons for folders and file types to improve list readability in pickers.
* **🛡️ Reference-Aware Rename:** Renaming a file updates all incoming links pointing to it (supports standard markdown links and images).
* **🆔 ID Generation:** Utilities to generate and insert unique IDs in YAML frontmatter.
* **⚡ Performance:** Optimized indexing using `fd` and `ripgrep`, with a native Lua fallback.

---

## ⚡ Requirements

* **Neovim >= 0.9.0**
* **[snacks.nvim](https://github.com/folke/snacks.nvim):** (Recommended) For modern UI pickers and image previews.
* **Dependencies (Optional but Recommended):**
    * `ripgrep` (for fast title extraction).
    * `fd` (for fast file scanning).
    * A **Nerd Font** (if enabling icons).

---

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "alchr/astereon.nvim",
  dependencies = { "folke/snacks.nvim" },
  -- Optional: Set up default keymaps here
  keys = {
    { "<leader>nn", "<cmd>AstereonNewNote<cr>", desc = "New Note" },
    { "<leader>nl", "<cmd>InsertMdLink<cr>",    desc = "Insert Link" },
    { "<leader>no", "<cmd>AstereonOpen<cr>",     desc = "Open Note" },
    { "<leader>mi", "<cmd>AstereonInsertMedia<cr>", desc = "Insert Media" },
    { "<leader>rf", "<cmd>AstereonRename<cr>",   desc = "Rename Note" },
  },
  opts = {
    -- Configuration goes here (see below)
  },
}

```

---

## ⚙️ Configuration

The plugin is configurable via the `setup` function. Here is an example with all available options:

```lua
require("astereon").setup({
  -- 1. Behavior & File Naming
  new_note = {
    lowercase_filename = true, -- Force filenames to lowercase (true/false)
  },
  
  -- 2. ID Generation (YAML Frontmatter)
  ids = {
    format = "%Y%m%d%H%M%S", -- Date format for the 'id' field
  },

  -- 3. UI & Icons
  icons = {
    enable = true,      -- Enable/Disable icons in pickers
    default_icon = " ", -- Fallback icon
    root_icon = " ",    -- Icon for the root directory (.)
    
    -- Custom folder icons
    custom = {
      ["mocs"] = " ",
      ["references"] = " ",
      ["archive"] = " ",
      ["daily"] = " ",
    },
    
    -- File type icons (for media pickers)
    files = {
      image = " ",
      video = " ",
      audio = "󰝚 ",
      pdf   = "󰈙 ",
      default = " ",
    },
  },

  -- 4. Media Handling
  media = {
    display = "filename", -- "filename" or "filename+path"
    embed_images = true,  -- Insert images as ![]()
    prompt_alt_for_images = true, -- Prompt for Alt Text on insertion
    
    snacks = {
      preview = true,     -- Enable preview panel
      preset = "vscode",  -- Snacks picker layout
    },
  },

  -- 5. Refactoring
  rename = {
    -- "auto": updates link text if it matches the filename.
    -- "keep": preserves original link text.
    update_link_text = "auto", 
  },
  
  -- 6. Daily Notes
  daily = {
    enable = true,
    folder = "daily", -- Folder relative to root
  },
})

```

---

## ⌨️ API & Commands

These are the core commands you can map in your `keys` configuration.

| Command | Recommended Key | Description |
| --- | --- | --- |
| `AstereonNewNote` | `<leader>nn` | Create a new note in a selected folder. |
| `InsertMdLink` | `<leader>nl` | Search and insert a link to an existing note. |
| `AstereonOpen` | `<leader>no` | Open a note via fuzzy finder. |
| `AstereonOpenFolder` | `<leader>nF` | Browse notes filtered by folder. |
| `AstereonInsertMedia` | `<leader>mi` | Search media files and insert as image/link. |
| `AstereonRename` | `<leader>rf` | Rename the current file and **update all references**. |
| `AstereonUpdateId` | `<leader>uy` | Regenerate/Insert the YAML ID for the current note. |
| `AstereonRefreshIndex` | - | Manually rebuild the file index (rarely needed). |
| `AstereonDailyToday` | - | Open (or create) today's daily note. |


