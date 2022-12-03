local api = vim.api
local level_resolver = require("folding.level_resolver")

---@class folding.state
local state = {
  ---@type { [number]: number }
  tick = {},
  ---@type { [number]: folding.LineLevel }
  line_level = {},
  ---@param cls folding.state
  get = function(cls, bufnr)
    if cls.tick[bufnr] == nil then return end
    local now = api.nvim_buf_get_changedtick(bufnr)
    if cls.tick[bufnr] ~= now then
      cls.tick[bufnr] = nil
      cls.line_level[bufnr] = nil
      return
    end
    return cls.line_level[bufnr]
  end,
  ---@param cls folding.state
  ---@param bufnr number
  ---@param tick number
  ---@param line_level folding.LineLevel
  set = function(cls, bufnr, tick, line_level)
    cls.tick[bufnr] = tick
    cls.line_level[bufnr] = line_level
  end,
}

---@return folding.fold_expr
local function expr_handler(ft)
  local resolver = level_resolver(ft)
  return function(lnum)
    lnum = lnum - 1
    local bufnr = api.nvim_get_current_buf()
    local line_level = state:get(bufnr)
    if line_level == nil then
      -- todo: mutex?
      line_level = resolver(bufnr)
      local tick = api.nvim_buf_get_changedtick(bufnr)
      state:set(bufnr, tick, line_level)
    end

    return line_level[lnum] or -1
  end
end

---@type { [string]: folding.fold_expr }
return setmetatable({}, {
  __index = function(t, key)
    t[key] = expr_handler(key)
    return t[key]
  end,
})
