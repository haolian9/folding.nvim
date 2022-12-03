Providing foldexpr for several languages based on nvim's treesitter

## status

* it is not a serious project
* it just works
* no more languages are planned
* supported languages: python, zig, lua, c, go

## prerequisites

* nvim 0.8.*

## usage

using ft=lua for example:
* `require'folding'.attach('lua')`
* you may want to put it in an autocmd or ftplugin/lua.{vim,lua}
