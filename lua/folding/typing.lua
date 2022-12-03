---@diagnostic disable

---@alias folding.LineLevel { [number]: number }
---@alias folding.tree_walker fun(cls: folding.TreeWalkers, line_level: folding.LineLevel, node: TSNode, parent_level: number)
---@alias folding.TreeWalkers { [string]: folding.tree_walker }
---@alias folding.tip_walker fun(cls: folding.TipWalkers, tree_walker: folding.tree_walker, line_level: folding.LineLevel, tip: TSNode)
---@alias folding.TipWalkers { [string]: folding.tip_walker }
---@alias folding.fold_expr fun(lnum: number): number
