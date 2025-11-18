-- Astereon.nvim — Markdown links & media + Safe rename (updates references)
-- Snacks integration (pickers) with fallback to vim.ui.select

local Index = require("astereon.index")

local M = {}
M.state = {
  daily = {
    current = nil,
  },
}

M.config = {
  -- Notes
  label_mode = "auto",            -- "auto" | "title" | "basename"
  scan_limit = 5000,
  ignore_dirs = { ".git", ".obsidian", "node_modules" },

  new_note_preferred_dirs = {},   -- e.g. { "aent", "atls" }
  new_note_template = nil,        -- function(title, slug, id) -> string
  open_new_note = false,          -- false | "edit" | "vsplit" | "split"

  -- Open-only flows
  open_pick_mode = "edit",        -- "edit" | "vsplit" | "split"

  -- Display presets (notes)
  display = {
    search_link        = "filename",     -- "label" | "filename" | "path" | "label+path" | "filename+path"
    folder_search_link = "label+path",
    open_pick          = "filename",
    open_folder_pick   = "label+path",
    snacks = {
      preview = false,
      preset = nil,
      layout = nil,
      show_index_numbers = nil,
    },
  },

  ids = {
    format = "%Y%m%d%H%M%S",
  },

  daily = {
    enable = false,
    folder = "apsn/dly",
    template = nil,                -- function(date, heading): string
    mappings = {
      today = "<leader>ot",
      next = "<leader>on",
      prev = "<leader>op",
    },
  },

  -- Media
  media = {
    exts = {
      ".png",".jpg",".jpeg",".webp",".gif",".svg",".bmp",".tiff",
      ".mp3",".wav",".flac",".m4a",
      ".mp4",".mov",".mkv",".webm",
      ".pdf",
    },
    image_exts = { ".png",".jpg",".jpeg",".webp",".gif",".svg",".bmp",".tiff" },
    display = "filename",         -- "filename" | "filename+path"
    embed_images = true,          -- if true, images insert as ![]()
    prompt_alt_for_images = true, -- ask alt on image insert
    snacks = {
      preview = false,            -- enable Snacks preview panel for media pickers
      preset = nil,               -- override picker preset (fallbacks to global snacks preset)
      layout = nil,               -- full layout table override
      show_index_numbers = nil,   -- override numbering specifically for media pickers
    },
  },

  -- Rename behavior
  rename = {
    include_images = true,          -- update ![](...)
    update_reference_style = true,  -- update "[ref]: url"
    update_link_text = "auto",      -- "keep" | "filename" | "title" | "auto"
    update_image_alt = "auto",      -- "keep" | "auto"
    filename_label_style = "spaces",-- "slug" | "spaces" | "titlecase"
    auto_prefers = "title",         -- "title" | "filename" for "auto"
  },

  -- Snacks integration
  snacks = {
    enable = true,
    preset = "vscode",
    show_index_numbers = true,
  },

  -- Built-in keymaps (prefer configuring them in your setup)
  set_default_keymaps = false,

  -- Auto index refresh
  auto_refresh = {
    enable = true,
    events = {
      "BufWritePost",
      "BufFilePost",
      "DirChanged",
    },
  },
}

-- ========= Path & small helpers =========

local function split_parts(path)
  local t = {}
  for seg in (path or ""):gsub("\\","/"):gmatch("[^/]+") do
    if seg ~= "" then
      table.insert(t, seg)
    end
  end
  return t
end

local function norm(path)
  if not path or path == "" then
    return ""
  end
  path = path:gsub("\\","/")
  path = vim.fn.fnamemodify(path, ":p")
  path = path:gsub("/+$","")
  return path
end

local function buf_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return norm(vim.fn.getcwd())
  end
  return norm(vim.fn.fnamemodify(name, ":p:h"))
end

local function relpath(from, to)
  from = norm(from)
  to   = norm(to)
  local from_parts = split_parts(from)
  local to_parts   = split_parts(to)
  local len = math.min(#from_parts, #to_parts)
  local idx = 1
  while idx <= len and from_parts[idx] == to_parts[idx] do
    idx = idx + 1
  end
  local rel_parts = {}
  for i = idx, #from_parts do
    table.insert(rel_parts, "..")
  end
  for i = idx, #to_parts do
    table.insert(rel_parts, to_parts[i])
  end
  local rel = table.concat(rel_parts, "/")
  if rel == "" then
    return "."
  end
  return rel
end

local function is_ignored(path)
  local ignore = M.config.ignore_dirs or {}
  local set = {}
  for _, d in ipairs(ignore) do
    set[d] = true
  end
  local parts = split_parts(path or "")
  for _, seg in ipairs(parts) do
    if set[seg] then
      return true
    end
  end
  return false
end

local function has_ext(name, exts)
  if not exts then
    return true
  end
  local lower = string.lower(name or "")
  for _, e in ipairs(exts) do
    if lower:sub(-#e) == e then
      return true
    end
  end
  return false
end

local function walk_files(root, exts)
  root = norm(root)
  local results = {}
  local limit = M.config.scan_limit or 5000

  local function scan(dir)
    if #results >= limit then
      return
    end
    local fd = vim.loop.fs_scandir(dir)
    if not fd then
      return
    end
    while true do
      local name, t = vim.loop.fs_scandir_next(fd)
      if not name then
        break
      end
      local full = dir .. "/" .. name
      if t == "directory" then
        if not is_ignored(full) then
          scan(full)
        end
      else
        if has_ext(name, exts) then
          table.insert(results, norm(full))
        end
      end
    end
  end

  scan(root)
  table.sort(results)
  return results
end

local function list_markdown_files(root)
  return walk_files(root, { ".md" })
end

local function is_markdown(path)
  return string.lower(path or ""):sub(-3) == ".md"
end

local function read_first_title(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  for line in f:lines() do
    local t = line:match("^%s*#%s+(.+)")
    if t then
      t = t:gsub("%s+#%s*$","")
      t = t:gsub("%s+$","")
      f:close()
      return t
    end
  end
  f:close()
  return nil
end

local function scan_note_index(root)
  root = norm(root)
  local files = list_markdown_files(root)
  local base = {}
  for _, path in ipairs(files) do
    local abs = norm(path)
    local stem = vim.fn.fnamemodify(abs, ":t:r")
    local rel_from_root = relpath(root, abs)
    local folder = rel_from_root:match("(.+)/[^/]+$") or "."
    local title = read_first_title(abs)
    table.insert(base, {
      path = abs,
      stem = stem,
      title = title,
      rel_from_root = rel_from_root,
      folder = folder,
    })
  end
  table.sort(base, function(a, b)
    return a.rel_from_root < b.rel_from_root
  end)
  return base
end

local function refresh_note_index(root)
  root = norm(root)
  return Index.refresh(root, function()
    return scan_note_index(root)
  end)
end

local function get_note_index(root)
  root = norm(root)
  local cached = Index.get_items(root)
  if cached then
    return cached
  end
  return refresh_note_index(root)
end

local function invalidate_index_for(path)
  path = norm(path)
  if path == "" then
    return
  end
  local root = norm(vim.fn.getcwd())
  local rel = relpath(root, path)
  if rel:sub(1,1) == "." or rel:find("..", 1, true) then
    return
  end
  Index.invalidate(root)
end

local function slugify(s)
  s = (s or ""):lower()
  s = s:gsub("[^%w]+","-")
  s = s:gsub("-+","-")
  s = s:gsub("^%-","")
  s = s:gsub("%-$","")
  if s == "" then
    s = "note-" .. os.date("%H%M%S")
  end
  return s
end

local function generate_note_id()
  local icfg = M.config.ids or {}
  local fmt = icfg.format or "%Y%m%d%H%M%S"
  local ok, value = pcall(os.date, fmt)
  if not ok or not value or value == "" then
    value = tostring(os.time())
  end
  return value
end

local function daily_heading(date_str)
  local day_names = { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }
  local month_names = { "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" }
  local year, month, day = date_str:match("^(%d+)%-(%d+)%-(%d+)$")
  if not year then
    return date_str
  end
  local now = os.time()
  local parts = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(os.date("%H", now)),
    min = tonumber(os.date("%M", now)),
    sec = tonumber(os.date("%S", now)),
  }
  local ts = os.time(parts)
  local day_name = day_names[tonumber(os.date("%w", ts)) + 1]
  local hour = tonumber(os.date("%I", now))
  local minute = os.date("%M", now)
  local second = os.date("%S", now)
  local am_pm = os.date("%p", now)
  return string.format("> 📓 %s, %02d de %s del año %s a las %02d:%s:%s %s",
    day_name, tonumber(day) or 0, month_names[tonumber(month)] or month, year, hour, minute, second, am_pm)
end

local function daily_today()
  return os.date("%Y-%m-%d")
end

local function daily_parse(date_str)
  local year, month, day = date_str:match("^(%d+)%-(%d+)%-(%d+)$")
  if not year then
    return nil
  end
  return { year = tonumber(year), month = tonumber(month), day = tonumber(day) }
end

local function daily_relative(date_str, offset)
  local parsed = daily_parse(date_str)
  if not parsed then
    return daily_today()
  end
  local ts = os.time(parsed) + (offset * 24 * 60 * 60)
  return os.date("%Y-%m-%d", ts)
end

local function default_daily_template(date, heading)
  return table.concat({
    "---",
    "mood:",
    "location:",
    "weather:",
    "bed_time:",
    "sleep_hours:",
    "nap_hours:",
    "get_up:",
    "flow_state:",
    "---",
    "",
    heading,
    "",
  }, "\n")
end

local function daily_folder_path()
  local dcfg = M.config.daily or {}
  local folder = dcfg.folder
  if not folder or folder == "" then
    return nil
  end
  local root = norm(vim.fn.getcwd())
  return norm(root .. "/" .. folder)
end

local function daily_open(date)
  local dcfg = M.config.daily or {}
  local folder = daily_folder_path()
  if not folder then
    vim.notify("Astereon: daily.folder is not configured", vim.log.levels.WARN)
    return
  end
  vim.fn.mkdir(folder, "p")
  local path = norm(folder .. "/" .. date .. ".md")
  local exists = vim.loop.fs_stat(path) ~= nil
  if not exists then
    local template = dcfg.template or default_daily_template
    local ok, content = pcall(template, date, daily_heading(date))
    if not ok or type(content) ~= "string" then
      content = default_daily_template(date, daily_heading(date))
    end
    local f = io.open(path, "w")
    if not f then
      vim.notify("Astereon: unable to create daily note at " .. path, vim.log.levels.ERROR)
      return
    end
    f:write(content)
    f:close()
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  M.state.daily.current = date
  if not exists then
    vim.notify("Astereon: daily note created for " .. date, vim.log.levels.INFO)
  end
end

local function daily_open_relative(offset)
  local base = M.state.daily.current or daily_today()
  local target = daily_relative(base, offset)
  daily_open(target)
end

local function titlecase(str)
  local out = {}
  for word in (str or ""):gmatch("%S+") do
    local first = word:sub(1,1):upper()
    local rest = word:sub(2)
    table.insert(out, first .. rest)
  end
  return table.concat(out, " ")
end

local function filename_label(stem)
  local cfg = M.config.rename or {}
  local style = cfg.filename_label_style or "spaces"
  if style == "slug" then
    return stem
  end
  local s = (stem or ""):gsub("[-_]+"," ")
  if style == "titlecase" then
    s = titlecase(s)
  end
  return s
end

local function resolve_item_label(stem, title, label_mode)
  local mode = label_mode or M.config.label_mode or "auto"
  local title_value = (title ~= nil and title ~= "") and title or nil
  if mode == "title" then
    return title_value or filename_label(stem)
  elseif mode == "basename" then
    return filename_label(stem)
  end

  local prefer = (M.config.rename and M.config.rename.auto_prefers) or "title"
  if prefer == "title" and title_value then
    return title_value
  elseif prefer == "filename" then
    return filename_label(stem)
  end
  return title_value or filename_label(stem)
end

local function compute_new_label(stem, title)
  local rcfg = M.config.rename or {}
  local mode = rcfg.update_link_text or "auto"
  local prefer = rcfg.auto_prefers or "title"

  local filename_lbl = filename_label(stem or "")
  local title_lbl = title ~= nil and title ~= "" and title or nil

  if mode == "keep" then
    return nil
  elseif mode == "filename" then
    return filename_lbl
  elseif mode == "title" then
    return title_lbl or filename_lbl
  else -- auto
    if prefer == "title" and title_lbl then
      return title_lbl
    elseif prefer == "filename" then
      return filename_lbl
    end
    return title_lbl or filename_lbl
  end
end

local function default_template(title, slug, id)
  return string.format([[---
id: %s
title: '%s'
aliases: ['%s']
status: 'draft'
---

# %s

]], id, title, slug, title)
end

local function rewrite_yaml_id(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_id = generate_note_id()
  local yaml_start, yaml_end
  for idx, line in ipairs(lines) do
    if line:match("^%s*%-%-%-%s*$") then
      if not yaml_start then
        yaml_start = idx
      else
        yaml_end = idx
        break
      end
    end
  end
  if yaml_start and yaml_end and yaml_end > yaml_start then
    local replaced = false
    for i = yaml_start + 1, yaml_end - 1 do
      if lines[i]:match("^%s*id%s*:") then
        local indent = lines[i]:match("^(%s*)") or ""
        lines[i] = indent .. "id: " .. new_id
        replaced = true
        break
      end
    end
    if not replaced then
      table.insert(lines, yaml_start + 1, "id: " .. new_id)
    end
  else
    table.insert(lines, 1, "---")
    table.insert(lines, 2, "id: " .. new_id)
    table.insert(lines, 3, "---")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.notify("Astereon: updated YAML id -> " .. new_id, vim.log.levels.INFO)
end

local function insert_text(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  local after  = line:sub(col + 1)
  local new_line = before .. text .. after
  vim.api.nvim_set_current_line(new_line)
  vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

local function is_image_path(path)
  local mcfg = M.config.media or {}
  local exts = mcfg.image_exts or {}
  local lower = string.lower(path or "")
  for _, e in ipairs(exts) do
    if lower:sub(-#e) == e then
      return true
    end
  end
  return false
end

-- ========= Snacks-aware UI wrappers =========

local function snacks_ok()
  local scfg = M.config.snacks or {}
  if not scfg.enable then
    return false
  end
  local ok, _ = pcall(require, "snacks")
  return ok
end

local function snacks_select(items, opts, on_choice)
  assert(type(on_choice) == "function", "on_choice must be a function")
  opts = opts or {}

  local scfg = M.config.snacks or {}
  local override = opts.snacks or {}
  local show_numbers = override.show_index_numbers
  if show_numbers == nil then
    show_numbers = scfg.show_index_numbers ~= false
  end
  local format_item = opts.format_item or tostring
  local get_file = override.get_file
  local get_title = override.get_title
  local get_cwd = override.get_cwd
  local finder_items = {}
  for idx, item in ipairs(items) do
    local text = format_item(item)
    local prefix = show_numbers and (idx .. " ") or ""
    local entry = {
      formatted = text,
      text = prefix .. text,
      item = item,
      idx = idx,
    }
    if get_file then
      entry.file = get_file(item)
    end
    if get_title then
      entry.title = get_title(item)
    end
    if get_cwd then
      entry.cwd = get_cwd(item)
    end
    table.insert(finder_items, entry)
  end

  local title = opts.prompt or "Select"
  title = title:gsub("^%s*", ""):gsub("[%s:]*$", "")

  local layout = override.layout or scfg.layout
  local preset = override.preset or scfg.preset or "vscode"
  if layout then
    layout = vim.deepcopy(layout)
  else
    layout = { preset = preset }
  end

  local Snacks = require("snacks")
  local completed = false

  local format_fn
  if show_numbers then
    format_fn = Snacks.picker.format.ui_select(opts.kind, #items)
  else
    format_fn = function(entry)
      return { { entry.formatted } }
    end
  end

  local preview = override.preview
  if preview == true then
    preview = "file"
  end

  return Snacks.picker.pick({
    source = "select",
    items = finder_items,
    format = format_fn,
    title = title,
    layout = layout,
    preview = preview,
    previewer = override.previewer,
    previewers = override.previewers,
    actions = {
      confirm = function(picker, item)
        if completed then
          return
        end
        completed = true
        picker:close()
        vim.schedule(function()
          on_choice(item and item.item, item and item.idx)
        end)
      end,
    },
    on_close = function()
      if completed then
        return
      end
      completed = true
      vim.schedule(on_choice)
    end,
  })
end

local function select_ui(items, opts, on_choice)
  opts = opts or {}
  if snacks_ok() then
    snacks_select(items, opts, on_choice)
  else
    vim.ui.select(items, { prompt = opts.prompt, format_item = opts.format_item }, on_choice)
  end
end

local function input_ui(opts, on_confirm)
  vim.ui.input(opts or {}, function(value)
    if value == nil or value == "" then
      on_confirm(nil)
    else
      on_confirm(value)
    end
  end)
end

-- ========= Items for pickers =========

local function build_note_items(root, here, label_mode)
  root = norm(root)
  here = norm(here)
  local base_items = get_note_index(root)
  local items = {}

  label_mode = label_mode or M.config.label_mode or "auto"

  for _, base in ipairs(base_items) do
    local label = resolve_item_label(base.stem, base.title, label_mode)
    table.insert(items, {
      path = base.path,
      stem = base.stem,
      title = base.title,
      label = label,
      rel_from_root = base.rel_from_root,
      folder = base.folder,
      rel_from_here = relpath(here, base.path),
    })
  end

  table.sort(items, function(a, b)
    return a.label < b.label
  end)

  return items
end

local function build_media_items(root, here)
  root = norm(root)
  here = norm(here)
  local mcfg = M.config.media or {}
  local files = walk_files(root, mcfg.exts or {})
  local items = {}

  for _, path in ipairs(files) do
    local abs = norm(path)
    local filename = vim.fn.fnamemodify(abs, ":t")
    local rel_from_root = relpath(root, abs)
    local folder = rel_from_root:match("(.+)/[^/]+$") or "."
    table.insert(items, {
      path = abs,
      filename = filename,
      rel_from_root = rel_from_root,
      folder = folder,
      rel_from_here = relpath(here, abs),
    })
  end

  table.sort(items, function(a, b)
    return a.filename < b.filename
  end)

  return items
end

local function media_snacks_options()
  local mcfg = M.config.media or {}
  local scfg = mcfg.snacks or {}
  if not (scfg and scfg.preview) then
    return nil
  end
  return {
    preview = scfg.preview,
    layout = scfg.layout,
    preset = scfg.preset,
    show_index_numbers = scfg.show_index_numbers,
    get_file = function(item)
      return item.path
    end,
    get_title = function(item)
      return item.filename
    end,
  }
end

local function note_snacks_options(section)
  local display = M.config.display or {}
  local scfg = display.snacks
  if type(scfg) ~= "table" then
    return nil
  end
  local base = scfg
  if type(scfg.default) == "table" then
    base = scfg.default
  end
  local opts = (section and type(scfg[section]) == "table" and scfg[section]) or base
  if type(opts) ~= "table" or not opts.preview then
    return nil
  end
  local merged = opts
  if opts ~= base and base then
    merged = vim.tbl_deep_extend("force", {}, base, opts)
  end
  return {
    preview = merged.preview,
    layout = merged.layout,
    preset = merged.preset,
    show_index_numbers = merged.show_index_numbers,
    get_file = function(item)
      return item.path
    end,
    get_title = function(item)
      return item.label or item.stem
    end,
  }
end

local function make_note_formatter(mode)
  return function(item)
    if type(item) ~= "table" then
      return tostring(item)
    end
    if mode == "label" then
      return item.label
    elseif mode == "filename" then
      return item.stem
    elseif mode == "path" then
      return item.rel_from_root
    elseif mode == "label+path" then
      return string.format("%s  ·  %s", item.label, item.rel_from_root)
    elseif mode == "filename+path" then
      return string.format("%s  ·  %s", item.stem, item.rel_from_root)
    else
      return item.label
    end
  end
end

local function make_media_formatter(mode)
  return function(item)
    if type(item) ~= "table" then
      return tostring(item)
    end
    if mode == "filename+path" then
      return string.format("%s  ·  %s", item.filename, item.rel_from_root)
    else
      return item.filename
    end
  end
end

local function ensure_rel(rel)
  if rel == "." then
    return "./"
  end
  if rel:sub(1,1) == "." or rel:sub(1,1) == "/" then
    return rel
  end
  return "./" .. rel
end

local function do_insert_link(label, rel)
  local href = ensure_rel(rel or "")
  local text = string.format("[%s](%s)", label, href)
  insert_text(text)
end

local function do_insert_media_link(item)
  local href = ensure_rel(item.rel_from_here)
  local mcfg = M.config.media or {}
  local is_img = is_image_path(item.path)

  if is_img and mcfg.embed_images then
    if mcfg.prompt_alt_for_images then
      input_ui({ prompt = " Image alt text:" }, function(alt)
        alt = alt or ""
        local text = string.format("![%s](%s)", alt, href)
        insert_text(text)
      end)
    else
      local text = string.format("![](%s)", href)
      insert_text(text)
    end
  else
    local stem = vim.fn.fnamemodify(item.filename, ":r")
    local label = filename_label(stem)
    local text = string.format("[%s](%s)", label, href)
    insert_text(text)
  end
end

-- ========= New note helper =========

local function create_note_ui(here, root, after_create_cb, open_mode)
  root = norm(root)
  here = norm(here)
  local base_items = get_note_index(root)
  local dirs = {}
  local set = {}
  for _, item in ipairs(base_items) do
    local folder = item.folder or "."
    if not set[folder] then
      set[folder] = true
      table.insert(dirs, folder)
    end
  end
  table.sort(dirs)

  local preferred, prefset = {}, {}
  for _, d in ipairs(M.config.new_note_preferred_dirs or {}) do
    local abs = norm(root .. "/" .. d)
    if vim.fn.isdirectory(abs) == 1 then
      table.insert(preferred, d)
      prefset[d] = true
    end
  end

  local choices = {}
  for _, d in ipairs(preferred) do
    table.insert(choices, d)
  end
  for _, d in ipairs(dirs) do
    if not prefset[d] then
      table.insert(choices, d)
    end
  end
  if #choices == 0 then
    choices = { "." }
  end

  select_ui(choices, { prompt = " Destination folder…" }, function(dir_rel)
    if not dir_rel then
      return
    end
    input_ui({ prompt = " New note title:" }, function(title)
      if not title or title == "" then
        return
      end
      local slug = slugify(title)
      local id   = generate_note_id()
      local template = M.config.new_note_template or default_template
      local content = template(title, slug, id)

      local target_dir = norm(root .. "/" .. dir_rel)
      vim.fn.mkdir(target_dir, "p")
      local path = norm(target_dir .. "/" .. slug .. ".md")

      if not vim.loop.fs_stat(path) then
        local f = io.open(path, "w")
        if f then
          f:write(content)
          f:close()
        end
      end

      Index.invalidate(root)

      local rel_for_here = relpath(here, path)
      if after_create_cb then
        after_create_cb(rel_for_here, title, path)
      end

      local mode = open_mode
      if mode == nil then
        mode = M.config.open_new_note
      end
      if mode == "edit" then
        vim.cmd.edit(path)
      elseif mode == "split" then
        vim.cmd.split(path)
      elseif mode == "vsplit" then
        vim.cmd.vsplit(path)
      end
    end)
  end)
end

-- ========= Note flows =========

function M.search_link(opts)
  opts = opts or {}
  local root, here = vim.fn.getcwd(), buf_dir()
  local label_mode = opts.label_mode or M.config.label_mode
  local items = build_note_items(root, here, label_mode)
  if #items == 0 then
    vim.notify("Astereon: no markdown notes found", vim.log.levels.WARN)
    return
  end
  local mode = (M.config.display and M.config.display.search_link) or "filename"
  select_ui(items, {
    prompt = " Insert link to note…",
    format_item = make_note_formatter(mode),
    snacks = note_snacks_options("search_link"),
  }, function(item)
    if not item then
      return
    end
    do_insert_link(item.label, item.rel_from_here)
  end)
end

function M.folder_search_link(opts)
  opts = opts or {}
  local root, here = vim.fn.getcwd(), buf_dir()
  local label_mode = opts.label_mode or M.config.label_mode
  local items = build_note_items(root, here, label_mode)
  if #items == 0 then
    vim.notify("Astereon: no markdown notes found", vim.log.levels.WARN)
    return
  end

  local folders_set = {}
  for _, it in ipairs(items) do
    folders_set[it.folder] = true
  end
  local folders = {}
  for f, _ in pairs(folders_set) do
    table.insert(folders, f)
  end
  table.sort(folders)

  select_ui(folders, { prompt = " Folder for note link…" }, function(folder)
    if not folder then
      return
    end
    local filtered = {}
    for _, it in ipairs(items) do
      if it.folder == folder then
        table.insert(filtered, it)
      end
    end
    if #filtered == 0 then
      vim.notify("Astereon: no notes in folder " .. folder, vim.log.levels.WARN)
      return
    end
    local mode = (M.config.display and M.config.display.folder_search_link) or "label+path"
    select_ui(filtered, {
      prompt = " Insert link to note…",
      format_item = make_note_formatter(mode),
      snacks = note_snacks_options("folder_search_link"),
    }, function(item)
      if not item then
        return
      end
      do_insert_link(item.label, item.rel_from_here)
    end)
  end)
end

function M.create_and_link(opts)
  opts = opts or {}
  local root, here = vim.fn.getcwd(), buf_dir()
  local label_mode = opts.label_mode or M.config.label_mode
  create_note_ui(here, root, function(rel, title, path)
    local stem = vim.fn.fnamemodify(path, ":t:r")
    local label = resolve_item_label(stem, title, label_mode)
    do_insert_link(label, rel)
  end, nil)
end

function M.create_note(opts)
  opts = opts or {}
  local root, here = vim.fn.getcwd(), buf_dir()
  local mode = opts.open_mode or "edit"
  create_note_ui(here, root, function(_, _, _) end, mode)
end

function M.open_pick()
  local root, here = vim.fn.getcwd(), buf_dir()
  local items = build_note_items(root, here, M.config.label_mode)
  if #items == 0 then
    vim.notify("Astereon: no markdown notes found", vim.log.levels.WARN)
    return
  end
  local mode = (M.config.display and M.config.display.open_pick) or "filename"
  select_ui(items, {
    prompt = " Open note…",
    format_item = make_note_formatter(mode),
    snacks = note_snacks_options("open_pick"),
  }, function(item)
    if not item then
      return
    end
    local open_mode = M.config.open_pick_mode or "edit"
    if open_mode == "split" then
      vim.cmd.split(item.path)
    elseif open_mode == "vsplit" then
      vim.cmd.vsplit(item.path)
    else
      vim.cmd.edit(item.path)
    end
  end)
end

function M.open_folder_pick()
  local root, here = vim.fn.getcwd(), buf_dir()
  local items = build_note_items(root, here, M.config.label_mode)
  if #items == 0 then
    vim.notify("Astereon: no markdown notes found", vim.log.levels.WARN)
    return
  end

  local folders_set = {}
  for _, it in ipairs(items) do
    folders_set[it.folder] = true
  end
  local folders = {}
  for f, _ in pairs(folders_set) do
    table.insert(folders, f)
  end
  table.sort(folders)

  select_ui(folders, { prompt = " Folder for note…" }, function(folder)
    if not folder then
      return
    end
    local filtered = {}
    for _, it in ipairs(items) do
      if it.folder == folder then
        table.insert(filtered, it)
      end
    end
    if #filtered == 0 then
      vim.notify("Astereon: no notes in folder " .. folder, vim.log.levels.WARN)
      return
    end
    local mode = (M.config.display and M.config.display.open_folder_pick) or "label+path"
    select_ui(filtered, {
      prompt = " Open note…",
      format_item = make_note_formatter(mode),
      snacks = note_snacks_options("open_folder_pick"),
    }, function(item)
      if not item then
        return
      end
      local open_mode = M.config.open_pick_mode or "edit"
      if open_mode == "split" then
        vim.cmd.split(item.path)
      elseif open_mode == "vsplit" then
        vim.cmd.vsplit(item.path)
      else
        vim.cmd.edit(item.path)
      end
    end)
  end)
end

-- ========= Media flows =========

function M.search_media_link()
  local root, here = vim.fn.getcwd(), buf_dir()
  local items = build_media_items(root, here)
  if #items == 0 then
    vim.notify("Astereon: no media files found", vim.log.levels.WARN)
    return
  end
  local mode = (M.config.media and M.config.media.display) or "filename"
  select_ui(items, {
    prompt = " Insert link to media…",
    format_item = make_media_formatter(mode),
    snacks = media_snacks_options(),
  }, function(item)
    if not item then
      return
    end
    do_insert_media_link(item)
  end)
end

function M.open_media_pick()
  local root, here = vim.fn.getcwd(), buf_dir()
  local items = build_media_items(root, here)
  if #items == 0 then
    vim.notify("Astereon: no media files found", vim.log.levels.WARN)
    return
  end
  local mode = (M.config.media and M.config.media.display) or "filename"
  select_ui(items, {
    prompt = " Open media…",
    format_item = make_media_formatter(mode),
    snacks = media_snacks_options(),
  }, function(item)
    if not item then
      return
    end
    vim.cmd.edit(item.path)
  end)
end

-- ========= Daily notes =========

function M.open_daily_today()
  M.state.daily.current = nil
  daily_open(daily_today())
end

function M.open_daily_next()
  daily_open_relative(1)
end

function M.open_daily_prev()
  daily_open_relative(-1)
end

function M.update_note_id()
  rewrite_yaml_id()
end

-- ========= Rename current file =========

local function prompt_overwrite(target_name, cb)
  select_ui({ "No", "Yes" }, { prompt = (" Overwrite %q?"):format(target_name) }, function(choice)
    cb(choice == "Yes")
  end)
end

local function process_links_in_file(fpath, old_abs, new_abs, label_for_note)
  local dir = norm(vim.fn.fnamemodify(fpath, ":p:h"))
  local old_rel = relpath(dir, old_abs)
  local new_rel = relpath(dir, new_abs)

  local rcfg = M.config.rename or {}
  local include_images = rcfg.include_images ~= false
  local update_ref = rcfg.update_reference_style ~= false
  local update_link_text_mode = rcfg.update_link_text or "auto"
  local update_image_alt_mode = rcfg.update_image_alt or "auto"

  local ok, lines = pcall(vim.fn.readfile, fpath)
  if not ok or type(lines) ~= "table" then
    return
  end

  local normalized_old = old_rel:gsub("^%./","")
  local changed = false

  for i, line in ipairs(lines) do
    local newline = line

    -- inline links and images: ![alt](url) or [text](url)
    newline = newline:gsub("(!?)%[([^%]]*)%]%(([^%)]+)%)", function(bang, text, url)
      local clean_url = url:gsub("%s+$","")
      local normalized_url = clean_url:gsub("^%./","")
      if normalized_url ~= normalized_old then
        return bang .. "[" .. text .. "](" .. url .. ")"
      end

      local is_img = (bang == "!")
      local new_url = new_rel
      local new_text = text

      if is_img then
        if include_images and update_image_alt_mode ~= "keep" then
          if label_for_note and label_for_note ~= "" then
            new_text = label_for_note
          end
        end
      else
        if update_link_text_mode ~= "keep" then
          if label_for_note and label_for_note ~= "" then
            new_text = label_for_note
          end
        end
      end

      changed = true
      return bang .. "[" .. new_text .. "](" .. new_url .. ")"
    end)

    if update_ref then
      newline = newline:gsub("^(%s*%[[^%]]+%]:%s*)(%S+)(.*)", function(prefix, url, rest)
        local normalized_url = url:gsub("^%./","")
        if normalized_url ~= normalized_old then
          return prefix .. url .. rest
        end
        changed = true
        return prefix .. new_rel .. rest
      end)
    end

    if newline ~= line then
      lines[i] = newline
    end
  end

  if changed then
    vim.fn.writefile(lines, fpath)
  end
end

function M.rename_current_file()
  local current = vim.api.nvim_buf_get_name(0)
  if current == "" then
    vim.notify("Astereon: current buffer has no file name", vim.log.levels.WARN)
    return
  end

  local old_abs = norm(vim.fn.fnamemodify(current, ":p"))
  local dir = norm(vim.fn.fnamemodify(old_abs, ":p:h"))
  local ext = old_abs:match("^.+(%.[^%.]+)$") or ""
  local default_name = vim.fn.fnamemodify(old_abs, ":t")

  input_ui({ prompt = " New file name:", default = default_name }, function(input)
    if not input or input == "" or input == default_name then
      return
    end
    local new_name = input
    if not new_name:match("%.[%w]+$") then
      new_name = new_name .. ext
    end
    local new_abs = norm(dir .. "/" .. new_name)
    if new_abs == old_abs then
      return
    end

    local function proceed()
      local ok, err = os.rename(old_abs, new_abs)
      if not ok then
        vim.notify("Astereon: rename failed: " .. tostring(err), vim.log.levels.ERROR)
        return
      end

      if vim.api.nvim_buf_get_name(0) == current then
        vim.api.nvim_buf_set_name(0, new_abs)
      end

      local title = read_first_title(new_abs)
      local stem = vim.fn.fnamemodify(new_abs, ":t:r")
      local label_for_note = compute_new_label(stem, title)

      local root = norm(vim.fn.getcwd())
      local files = list_markdown_files(root)
      for _, f in ipairs(files) do
        process_links_in_file(f, old_abs, new_abs, label_for_note)
      end
      Index.invalidate(root)

      vim.notify("Astereon: file renamed and links updated", vim.log.levels.INFO)
    end

    if vim.loop.fs_stat(new_abs) then
      prompt_overwrite(new_abs, function(ok)
        if ok then
          os.remove(new_abs)
          proceed()
        end
      end)
    else
      proceed()
    end
  end)
end

function M.refresh_index()
  local root = norm(vim.fn.getcwd())
  refresh_note_index(root)
  vim.notify("Astereon: note index refreshed", vim.log.levels.INFO)
end

local function setup_auto_refresh()
  local cfg = M.config.auto_refresh or {}
  if cfg.enable == false then
    return
  end
  local events = cfg.events or { "BufWritePost", "BufFilePost", "DirChanged" }
  local group = vim.api.nvim_create_augroup("AstereonAutoRefresh", { clear = true })
  vim.api.nvim_create_autocmd(events, {
    group = group,
    callback = function(params)
      local event = params.event
      if event == "DirChanged" then
        Index.invalidate(norm(vim.fn.getcwd()))
        return
      end
      local file = params.match or params.file or ""
      if file == "" then
        return
      end
      if is_markdown(file) then
        invalidate_index_for(file)
      end
    end,
  })
end

-- ========= Setup =========

function M.setup(cfg)
  M.config = vim.tbl_deep_extend("force", M.config, cfg or {})
  setup_auto_refresh()

  vim.api.nvim_create_user_command("InsertMdLink", function(o)
    local arg = o.args
    local lm
    if arg == "auto" or arg == "title" or arg == "basename" then
      lm = arg
    end
    M.search_link({ label_mode = lm })
  end, {
    nargs = "?",
    complete = function()
      return { "auto", "title", "basename" }
    end,
  })

  vim.api.nvim_create_user_command("AstereonNewNote", function()
    M.create_note({ open_mode = "edit" })
  end, {})

  vim.api.nvim_create_user_command("AstereonRename", function()
    M.rename_current_file()
  end, {})

  vim.api.nvim_create_user_command("AstereonRefreshIndex", function()
    M.refresh_index()
  end, {})

  vim.api.nvim_create_user_command("AstereonOpen", function()
    M.open_pick()
  end, {})

  vim.api.nvim_create_user_command("AstereonOpenFolder", function()
    M.open_folder_pick()
  end, {})

  vim.api.nvim_create_user_command("AstereonUpdateId", function()
    M.update_note_id()
  end, {})

  if (M.config.daily and M.config.daily.enable) then
    vim.api.nvim_create_user_command("AstereonDailyToday", function()
      M.open_daily_today()
    end, {})
    vim.api.nvim_create_user_command("AstereonDailyNext", function()
      M.open_daily_next()
    end, {})
    vim.api.nvim_create_user_command("AstereonDailyPrev", function()
      M.open_daily_prev()
    end, {})
  end

  if M.config.set_default_keymaps then
    local map = vim.keymap.set
    map("n", "<leader>nn", function() M.create_note({ open_mode = "edit" }) end,
      { desc = "Astereon: create note" })
    map("n", "<leader>nL", function() M.create_and_link() end,    { desc = "Astereon: create note + link" })
    map("n", "<leader>nl", function() M.search_link() end,        { desc = "Astereon: insert note link" })
    map("n", "<leader>nf", function() M.folder_search_link() end, { desc = "Astereon: folder link" })
    map("n", "<leader>no", function() M.open_pick() end,          { desc = "Astereon: open note" })
    map("n", "<leader>nF", function() M.open_folder_pick() end,   { desc = "Astereon: open by folder" })
    map("n", "<leader>mi", function() M.search_media_link() end,  { desc = "Astereon: insert media link" })
    map("n", "<leader>mo", function() M.open_media_pick() end,    { desc = "Astereon: open media" })
    map("n", "<leader>rf", function() M.rename_current_file() end, { desc = "Astereon: rename note" })
    map("n", "<leader>uy", function() M.update_note_id() end,     { desc = "Astereon: regenerate YAML id" })

    local dcfg = M.config.daily or {}
    if dcfg.enable and dcfg.mappings then
      if dcfg.mappings.today then
        map("n", dcfg.mappings.today, function() M.open_daily_today() end,
          { desc = "Astereon: open today's daily note" })
      end
      if dcfg.mappings.next then
        map("n", dcfg.mappings.next, function() M.open_daily_next() end,
          { desc = "Astereon: open next daily note" })
      end
      if dcfg.mappings.prev then
        map("n", dcfg.mappings.prev, function() M.open_daily_prev() end,
          { desc = "Astereon: open previous daily note" })
      end
    end
  end
end

return M
