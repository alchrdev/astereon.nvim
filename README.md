# 🌟 astereon.nvim

Markdown link and media management for Neovim, with a focus on workspace integrity and file portability.

*Astereon was built for personal use to bridge the gap between Obsidian's organization and Neovim's editing power, without falling into vendor lock-in.*

---

## 💭 Why this exists

Many note-taking apps rely on WikiLinks (`[[Note]]`). While convenient, they often break when viewing notes in plain text editors, git web interfaces, or static site generators. 

Astereon automates the use of **standard Markdown links** (`[Title](path/to/note.md)`). This ensures your knowledge base remains fully navigable in any environment—Neovim, VSCode, GitHub, or a simple terminal—without requiring proprietary translation layers.

## ✨ Capabilities

*   **🔗 Link Management:** Insert links to notes with automatic spacing and label handling.
*   **🖼️ Media Handling:** Embed images, audio, and video with icons and previews (via `snacks.nvim`).
*   **🛡️ Integrity:** Renaming or moving a file updates all incoming links across the workspace automatically.
*   **🚀 Templating:** Simple Lua-based templates for new notes (supports IDs and frontmatter).
*   **📅 Daily Notes:** Basic workflow to open or create today's, yesterday's, or tomorrow's notes.
*   **⚡ Indexing:** Uses `fd` and `ripgrep` for fast file and title scanning.

## 📦 Requirements

*   **Neovim >= 0.9.0**
*   **[snacks.nvim](https://github.com/folke/snacks.nvim):** Recommended for UI pickers and previews.
*   **Dependencies:** `fd` and `ripgrep` (optional but recommended for speed).

## ⚙️ Installation & Setup

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "alchr/astereon.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    set_default_keymaps = true,
    daily = {
      enable = true,
      folder = "notes/daily",
    },
  },
}
```

### Configuration Defaults

```lua
require("astereon").setup({
  label_mode = "auto", -- "auto" | "title" | "basename"
  new_note = {
    lowercase_filename = true,
    preferred_dirs = { "inbox", "projects" }, 
  },
  templates = {
    default = function(title, slug, id)
      return "---\nid: " .. id .. "\ntitle: '" .. title .. "'\n---\n\n# " .. title .. "\n\n"
    end,
  },
  media = {
    embed_images = true,
    prompt_alt_for_images = true,
  },
})
```

## ⌨️ Commands & Keymaps

If `set_default_keymaps = true`, the following bindings are created:

| Action | Keymap | Command |
| --- | --- | --- |
| Create new note | `<leader>nn` | `AstereonNewNote` |
| Insert link | `<leader>nl` | `InsertMdLink` |
| Open note | `<leader>no" | `AstereonOpen` |
| Insert media | `<leader>mi` | `AstereonInsertMedia` |
| Rename & Update | `<leader>rf` | `AstereonRename` |
| Delete safely | `<leader>nd` | `AstereonDelete` |
| Today's note | `<leader>ot` | `AstereonDailyToday` |

## 🏗️ Technical Note

The rename engine uses `nvim_buf_call` to ensure that even during asynchronous operations, the buffer synchronization and reference updates happen in the correct context, preventing common race conditions in Neovim.
