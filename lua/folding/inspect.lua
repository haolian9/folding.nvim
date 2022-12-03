local api = vim.api
local level_resolver = require("folding.level_resolver")

return function()
  local bufnr = api.nvim_get_current_buf()
  local line_level = level_resolver(vim.bo[bufnr].filetype)(bufnr)

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
  api.nvim_cmd({ cmd = "vsplit", mods = { split = "aboveleft" } }, {})
  local new_win_id = api.nvim_get_current_win()
  api.nvim_win_set_width(new_win_id, 20)
  local wo = vim.wo[new_win_id]
  wo.number = true
  wo.relativenumber = false
  api.nvim_win_set_buf(new_win_id, new_bufnr)
end
