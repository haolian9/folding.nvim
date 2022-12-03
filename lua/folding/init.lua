local M = {}

local api = vim.api

function M.attach(ft)
  local win_id = api.nvim_get_current_win()
  if ft == nil then
    local bufnr = api.nvim_win_get_buf(win_id)
    ft = api.nvim_buf_get_option(bufnr, "filetype")
  end
  local wo = vim.wo[win_id]

  wo.foldmethod = "expr"
  wo.foldlevel = 1
  wo.foldexpr = string.format([[v:lua.require'folding.exprs'.%s(v:lnum)]], ft)
end

return M
