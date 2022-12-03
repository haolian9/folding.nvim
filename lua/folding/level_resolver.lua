--[[
python spec
* additional body node
* no closing row

lua spec
* additional body node

c spec
* inline vs newline {
--]]

local ts = vim.treesitter

---@type folding.TreeWalkers
local tree_walkers = {}
do
  function tree_walkers.lua(cls, line_level, node, parent_level)
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
      cls:lua(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers.zig(cls, line_level, node, parent_level)
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
      cls:zig(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers.python(cls, line_level, node, parent_level)
    local r0 = node:start()
    local my_level = parent_level
    if node:type() ~= "block" then
      if line_level[r0] == nil then
        my_level = parent_level + 1
        line_level[r0] = my_level
      end
    end
    for i = 0, node:named_child_count() - 1 do
      cls:python(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers.c(cls, line_level, node, parent_level)
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
      cls:c(line_level, node:named_child(i), my_level)
    end
  end

  tree_walkers.go = tree_walkers.zig
end

---@type folding.TipWalkers
local tip_walkers = {}
do
  function tip_walkers.zig(cls, tree_walker, line_level, tip)
    _ = cls
    local r0, _, r1, _ = tip:range()
    local lv = r0 ~= r1 and 1 or 0
    line_level[r0] = lv
    line_level[r1] = lv
    if r0 == r1 then return end
    for i = 0, tip:named_child_count() - 1 do
      tree_walker(tree_walkers, line_level, tip:named_child(i), lv)
    end
  end

  function tip_walkers.python(cls, tree_walker, line_level, tip)
    _ = cls
    local r0, _, r1, _ = tip:range()
    local lv = r0 ~= r1 and 1 or 0
    line_level[r0] = lv
    if r0 == r1 then return end
    for i = 0, tip:named_child_count() - 1 do
      tree_walker(tree_walkers, line_level, tip:named_child(i), lv)
    end
  end

  tip_walkers.lua = tip_walkers.zig
  tip_walkers.go = tip_walkers.zig
  tip_walkers.c = tip_walkers.zig
end

--:h fold-expr
---@param ft string
---@return fun(bufnr: number): folding.LineLevel
return function(ft)
  local walk_tip = assert(tip_walkers[ft], "unsupported tip_walker for ft=" .. ft)
  local walk_tree = assert(tree_walkers[ft], "unsupported tree_walker for ft=" .. ft)

  return function(bufnr)
    ---@type TSNode
    local root
    do
      local parser = ts.get_parser(bufnr)
      local trees = parser:trees()
      assert(#trees == 1)
      root = trees[1]:root()
    end

    ---@type folding.LineLevel
    local line_level = {}

    for i = 0, root:named_child_count() - 1 do
      walk_tip(tip_walkers, walk_tree, line_level, root:named_child(i))
    end

    return line_level
  end
end
