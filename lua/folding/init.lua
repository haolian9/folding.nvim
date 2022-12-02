--[[
python spec
* additional body node
* no closing row

lua spec
* additional body node
--]]

local M = {}

local ts = vim.treesitter
local api = vim.api

---@alias LineLevel {[number]:number}

--:h fold-expr
---@param ft string
---@return fun(bufnr:number)LineLevel
local function level_resolver(ft)
  local walk_tree
  if ft == "lua" then
    ---@param line_level LineLevel
    ---@param node TSNode
    ---@param parent_level number
    walk_tree = function(line_level, node, parent_level)
      local r0, _, r1, _ = node:range()
      local my_level = parent_level
      if node:type() ~= "block" then
        if line_level[r0] == nil then
          my_level = parent_level + 1
          line_level[r0] = my_level
        end
        if line_level[r1] == nil then
          my_level = parent_level + 1
          line_level[r1] = my_level
        end
      end
      for i = 0, node:named_child_count() - 1 do
        walk_tree(line_level, node:named_child(i), my_level)
      end
    end
  elseif ft == "zig" then
    ---@param line_level LineLevel
    ---@param node TSNode
    ---@param parent_level number
    walk_tree = function(line_level, node, parent_level)
      local r0, _, r1, _ = node:range()
      local my_level = parent_level
      if line_level[r0] == nil then
        my_level = parent_level + 1
        line_level[r0] = my_level
      end
      if line_level[r1] == nil then
        my_level = parent_level + 1
        line_level[r1] = my_level
      end
      for i = 0, node:named_child_count() - 1 do
        walk_tree(line_level, node:named_child(i), my_level)
      end
    end
  elseif ft == "python" then
    ---@param line_level LineLevel
    ---@param node TSNode
    ---@param parent_level number
    walk_tree = function(line_level, node, parent_level)
      local r0 = node:start()
      local my_level = parent_level
      if node:type() ~= "block" then
        if line_level[r0] == nil then
          my_level = parent_level + 1
          line_level[r0] = my_level
        end
      end
      for i = 0, node:named_child_count() - 1 do
        walk_tree(line_level, node:named_child(i), my_level)
      end
    end
  else
    error("unreachable: unsupported ft for walk_tree")
  end

  local walk_tip
  if ft == "lua" or ft == "zig" then
    ---@param line_level LineLevel
    ---@param tip TSNode
    walk_tip = function(line_level, tip)
      local r0, _, r1, _ = tip:range()
      local lv = r0 ~= r1 and 1 or 0
      line_level[r0] = lv
      line_level[r1] = lv
      if r0 == r1 then return end
      for i = 0, tip:named_child_count() - 1 do
        walk_tree(line_level, tip:named_child(i), lv)
      end
    end
  elseif ft == "python" then
    ---@param line_level LineLevel
    ---@param tip TSNode
    walk_tip = function(line_level, tip)
      local r0, _, r1, _ = tip:range()
      local lv = r0 ~= r1 and 1 or 0
      line_level[r0] = lv
      if r0 == r1 then return end
      for i = 0, tip:named_child_count() - 1 do
        walk_tree(line_level, tip:named_child(i), lv)
      end
    end
  else
    error("unreachable: unsupported ft for walk_tip")
  end

  ---@param bufnr number
  ---@return LineLevel
  return function(bufnr)
    ---@type TSNode
    local root
    do
      local parser = ts.get_parser(bufnr)
      local trees = parser:trees()
      assert(#trees == 1)
      root = trees[1]:root()
    end

    ---@type LineLevel
    local line_level = {}

    for i = 0, root:named_child_count() - 1 do
      walk_tip(line_level, root:named_child(i))
    end

    return line_level
  end
end

do
  ---@class folding.luaspec.state
  local state = {
    ---@type { [number]: number}
    tick = {},
    ---@type { [number]: { [number]: number } }
    line_level = {},
    ---@param cls folding.luaspec.state
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
    ---@param cls folding.luaspec.state
    set = function(cls, bufnr, tick, line_level)
      cls.tick[bufnr] = tick
      cls.line_level[bufnr] = line_level
    end,
  }

  local function expr_handler(ft)
    local resolver = level_resolver(ft)
    ---@type fun(lnum:number)number
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

  M.expr_lua = expr_handler("lua")
  M.expr_zig = expr_handler("zig")
  M.expr_python = expr_handler("python")

  function M.inspect()
    local bufnr = api.nvim_get_current_buf()
    local line_level = state:get(bufnr)
    if line_level == nil then
      local resolver = level_resolver(api.nvim_buf_get_option(bufnr, "filetype"))
      line_level = resolver(bufnr)
      local tick = api.nvim_buf_get_changedtick(bufnr)
      state:set(bufnr, tick, line_level)
    end

    local line_count = api.nvim_buf_line_count(bufnr)
    local new_bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(new_bufnr, "bufhidden", "wipe")
    local lines = {}
    for i = 0, line_count do
      local lv = line_level[i]
      if lv == nil then
        table.insert(lines, "")
      else
        table.insert(lines, string.format("%s|%d", string.rep(" ", lv), lv))
      end
    end
    api.nvim_buf_set_lines(new_bufnr, 0, -1, false, lines)
    api.nvim_cmd({ cmd = "vsplit" }, {})
    local new_win_id = api.nvim_get_current_win()
    api.nvim_win_set_buf(new_win_id, new_bufnr)
  end
end

function M.attach(ft)
  local expr_fn = string.format("expr_%s", ft)
  if M[expr_fn] == nil then error("unsupported ft for folding") end

  local wo = vim.wo[api.nvim_get_current_win()]
  wo.foldmethod = "expr"
  wo.foldlevel = 1
  wo.foldexpr = string.format([[v:lua.require'folding'.%s(v:lnum)]], expr_fn)
end

return M
