local Index = {}

Index.state = {
  notes = {},
}

local function ensure_state(root)
  local entry = Index.state.notes[root]
  if not entry then
    entry = {}
    Index.state.notes[root] = entry
  end
  return entry
end

function Index.get_items(root)
  local entry = Index.state.notes[root]
  if entry and entry.items then
    return entry.items
  end
  return nil
end

function Index.refresh(root, builder)
  local items = {}
  if type(builder) == "function" then
    local ok, result = pcall(builder)
    if ok and type(result) == "table" then
      items = result
    else
      local message = ok and "result is not a table" or result
      vim.notify(string.format("RoadWeaver: index refresh failed (%s)", message), vim.log.levels.ERROR)
    end
  end
  local entry = ensure_state(root)
  entry.items = items
  entry.refreshed_at = vim.loop.hrtime()
  return items
end

function Index.invalidate(root)
  if root then
    Index.state.notes[root] = nil
  else
    Index.state.notes = {}
  end
end

return Index
