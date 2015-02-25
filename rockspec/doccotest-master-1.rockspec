package = "doccotest"
version = "master-1"

source = {
  url = "git://github.com/saucisson/lua-doccotest",
}

description = {
  summary     = "Doctest for Lua commented with Docco",
  detailed    = [[]],
  license     = "MIT/X11",
  maintainer  = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "lua_cliargs ~> 2",
  "i18n ~> 0",
  "ansicolors ~> 1",
  "rings ~> 1",
  "lualogging ~> 1",
}

build = {
  type    = "builtin",
  modules = {
    ["doccotest"] = "src/doccotest.lua",
  },
  install = {
    bin = {
      ["doccotest"] = "bin/doccotest",
    },
  },
}

