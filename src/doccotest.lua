#! /usr/bin/env lua

local defaults = {
  interface="TAP",
}

if _G.cli then
  return defaults
end

local cli       = require "cliargs"
local i18n      = require "i18n"
local rings     = require "rings"
local logging   = require "logging"
logging.console = require "logging.console"
local logger    = logging.console "%message\n"

_G.cli = cli

i18n.load {
  en = {
    ["input-help"   ] = "path to the source code file",
    ["output-help"  ] = "output format: TAP",
    ["verbose-help" ] = "enable verbose mode",
    ["read-success" ] = "Input file opened for reading.",
    ["read-error"   ] = "Cannot read input file, because: %{message}.",
    ["no-prompt"    ] = "Chunk at %{filename}:%{from}--%{to} does not start with a prompt.",
    ["chunk-success"] = "Execution of chunk at %{filename}:%{from}--%{to} is successful.",
    ["chunk-error"  ] = "Execution of chunk at %{filename}:%{from}--%{to} failed, because: %{message}.",
  }
}
local lang = os.getenv "LANG"
i18n.setLocale (lang)

cli:set_name (arg [0])

cli:add_argument (
  "input",
  i18n "input-help"
)

cli:add_option (
  "--output=<format>",
  i18n "output-help",
  tostring (defaults.interface)
)
cli:add_flag (
  "-v, --verbose",
  i18n "verbose-help"
)
local args = cli:parse_args ()
if not args then
  cli:print_help ()
  os.exit (1)
end

local input        = args.input
local output       = args.output
local verbose_mode = args.verbose

if verbose_mode then
  logger:setLevel (logging.DEBUG)
else
  logger:setLevel (logging.INFO)
end

--    > y = 1
--    > x = 1
--    >> print (x)
--    1
--    > x = 1
--    >> print x y

local file, err = io.open (input, "r")
if file then
  logger:debug (i18n "read-success")
else
  logger:error (i18n ("read-error", { message = err }))
  os.exit (1)
end

local sessions = {}
do
  local line_number = 0
  local from        = nil
  local to          = nil
  local buffer      = {}
  for line in file:lines () do
    line_number = line_number + 1
    local comment = line:match "^%s*%-%-(.*)"
    if comment then
      local code = comment:match "^    (.*)"
                or comment:match "^%t(.*)"
      if code then
        if not from then
          from = line_number
        end
        to = line_number
        buffer [#buffer+1] = code
      end
    end
    if from and to ~= line_number then
      sessions [#sessions+1] = {
        from   = from,
        to     = to,
        buffer = buffer,
      }
      from   = nil
      to     = nil
      buffer = {}
    end
  end
end
for i = 1, #sessions do
  local session = sessions [i]
  local buffer  = session.buffer
  local current = 1
  while current <= #buffer do
    local from    = nil
    local to      = nil
    local code   = {}
    local result = {}
    do
      local prompt = buffer [current]:match "^%s*>%s+(.*)"
      if not prompt then
        break
      end
      code [#code+1] = prompt
      from    = current
      current = current + 1
    end
    for i = current, #buffer do
      local prompt = buffer [current]:match "^%s*>>%s+(.*)"
      if not prompt then
        break
      end
      code [#code+1] = prompt
      current = current + 1
    end
    for i = current, #buffer do
      local prompt = buffer [current]:match "^%s*>>? (.*)"
      if prompt then
        break
      end
      result [#result+1] = buffer [from]
      current = current + 1
    end
    to = current - 1
    local ring    = rings.new ()
    ring:dostring [[
function print (...)
  local args = { ... }
  for i = 1, #args do
    io.write (tostring (args [i]))
    if i ~= #args then
      io.write "\t"
    end
  end
  io.write "\n"
end
io.stdout = io.tmpfile ()
io.stderr = io.tmpfile ()
io.output (io.stdout)
]]
    local ok, err = ring:dostring (table.concat (code, "\n"))
    local _, stdout, stderr = ring:dostring [[
io.stdout:seek "set"
io.stderr:seek "set"
return io.stdout:read "*all", io.stderr:read "*all"
]]
    if ok then
      logger:debug (i18n ("chunk-success", {
        filename = input,
        from     = session.from + from - 1,
        to       = session.from + to   - 1,
      }))
    else
      logger:warn (i18n ("chunk-error", {
        filename = input,
        from     = session.from + from - 1,
        to       = session.from + to   - 1,
        message  = err,
      }))
    end
    ring:close ()
  end
end
file:close ()