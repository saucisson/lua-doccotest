#! /usr/bin/env lua

local defaults = {
  format="TAP",
  output="test-results.txt",
}

if _G.cli then
  return defaults
end

local cli        = require "cliargs"
local i18n       = require "i18n"
local colors     = require "ansicolors"
local rings      = require "rings"
local logging    = require "logging"
logging.console  = require "logging.console"
local logger     = logging.console "%message\n"

_G.cli = cli
local string_metatable = getmetatable ""
string_metatable.__mod = require "i18n.interpolate"

do
  local lang = os.getenv "LANG"
  local language, variant = lang:match "^(%l+)_(%u+)"
  local default_locale = require "doccotest.en"
  i18n.load (default_locale)
  local ok, locale
  ok, locale = pcall (require, "doccotest." .. language)
  if ok then
    i18n.load (locale)
  end
  local ok, locale
  ok, locale = pcall (require, "doccotest." .. language .. "_" .. variant)
  if ok then
    i18n.load (locale)
  end
  i18n.setLocale (lang)
end

local function translate (string, t)
  string = i18n (string, t)
  string = string:gsub ("!{", "%%{")
  string = colors (string)
  return string
end

cli:set_name (arg [0])
cli:add_argument (
  "input",
  i18n "input-help"
)
cli:optarg (
  "inputs",
  i18n "inputs-help"
)
cli:add_option (
  "--output=<filename>",
  i18n "output-help",
  tostring (defaults.output)
)
cli:add_option (
  "--format=<format>",
  i18n "format-help",
  tostring (defaults.format)
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

if type (args.inputs) == "string" and args.inputs ~= "" then
  args.inputs = { args.inputs }
end
table.insert (args.inputs, 1, args.input)

if args.verbose then
  logger:setLevel (logging.DEBUG)
else
  logger:setLevel (logging.INFO)
end

do
  if args.format:lower () == "tap" then
    -- ok
  else
    logger:error (translate ("unknown-format", {
      args.format,
    }))
    os.exit (1)
  end
end

--    > y = 1
--    > x = 1
--    >> print (x)
--    1
--            (...)

--    > x = 1
--    >> print x y

--    > local x = 1
--    >> error "Ahah!"
--    >> x = 2
--    ... Ahah!

local tests = {}

for i = 1, #args.inputs do
  local filename  = args.inputs [i]
  local file, err = io.open (filename, "r")
  if not file then
    logger:error (translate ("read-failure", {
      filename = filename,
      message  = err,
    }))
  else
    logger:debug (translate ("read-success", {
      filename = filename,
    }))
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
    local ring = nil
    for i = 1, #sessions do
      if not ring then
        ring = rings.new ()
      end
      local session = sessions [i]
      local buffer  = session.buffer
      local current = 1
      while current <= #buffer do
        local from
        local to
        local code   = {}
        local result = {}
        do
          local prompt = buffer [current]:match "^%s*>%s+(.*)"
          if not prompt then
            logger:debug (translate ("no-prompt", {
              filename = filename,
              from     = session.from + from - 1,
              to       = session.from + to   - 1,
            }))
            break
          end
          code [#code+1] = prompt
          from    = current
          current = current + 1
        end
        for _ = current, #buffer do
          local prompt = buffer [current]:match "^%s*>>%s+(.*)"
          if not prompt then
            break
          end
          code [#code+1] = prompt
          current = current + 1
        end
        for _ = current, #buffer do
          local prompt = buffer [current]:match "^%s*>>? (.*)"
          if prompt then
            break
          end
          result [#result+1] = buffer [current]
          current = current + 1
        end
        to = current - 1
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
        local to_run  =
[[
local code = [=====[]] .. table.concat (code, "\n") .. [[
]=====]
local ok, err
res, err = loadstring (code)
if not res then
  io.stdout:write (err)
else
  res, err = pcall (res)
  if not res then
    io.stdout:write (err)
  end
end
]]
        local ok, err = ring:dostring (to_run)
        local _, stdout, stderr = ring:dostring [[
io.stdout:seek "set"
io.stderr:seek "set"
return io.stdout:read "*all", io.stderr:read "*all"
]]
        if ok then
          logger:debug (translate ("chunk-success", {
            filename = filename,
            from     = session.from + from - 1,
            to       = session.from + to   - 1,
          }))
        else
          logger:warn (translate ("chunk-failure", {
            filename = filename,
            from     = session.from + from - 1,
            to       = session.from + to   - 1,
            message  = err,
          }))
        end
        local patterns = {}
        for i = 1, #result do
          local line = result [i]
          if not line:match "^%s*%(%.%.%.%)%s*$" then
            -- http://stackoverflow.com/questions/9790688/escaping-strings-for-gsub
            line = line:gsub ('%%', '%%%%')
                       :gsub ('%^', '%%%^')
                       :gsub ('%$', '%%%$')
                       :gsub ('%(', '%%%(')
                       :gsub ('%)', '%%%)')
                       :gsub ('%.', '%%%.')
                       :gsub ('%[', '%%%[')
                       :gsub ('%]', '%%%]')
                       :gsub ('%*', '%%%*')
                       :gsub ('%+', '%%%+')
                       :gsub ('%-', '%%%-')
                       :gsub ('%?', '%%%?')
                       :gsub ("%%%.%%%.%%%.", ".*")
            line = "%s*" .. line .. "%s*"
            patterns [i] = line
          end
        end
        local pattern = "^" .. table.concat (patterns, "[\r\n]+") .. "$"
        if stdout:match (pattern) then
          logger:info (translate ("test-success", {
            filename = filename,
            from     = session.from,
            to       = session.to,
          }))
          tests [#tests+1] = {
            id       = #tests + 1,
            filename = filename,
            from     = session.from,
            to       = session.to,
            success  = true,
          }
        else
          logger:info (translate ("test-failure", {
            filename = filename,
            from     = session.from,
            to       = session.to,
            stdout   = stdout,
            stderr   = stderr,
          }))
          tests [#tests+1] = {
            id       = #tests + 1,
            filename = filename,
            from     = session.from,
            to       = session.to,
            success  = false,
            message  = stdout,
          }
        end
      end
      if buffer [#buffer]:match "%(%.%.%.%)%s*$" then
        logger:debug (translate ("ring-keep", {
          filename = filename,
          from     = session.from,
          to       = session.to,
        }))
      else
        ring:close ()
        ring = nil
        logger:debug (translate ("ring-close", {
          filename = filename,
          from     = session.from,
          to       = session.to,
        }))
      end
    end
    file:close ()
  end
end


if args.format:lower () == "tap" then
  local filename  = args.output
  local file, err = io.open (filename, "w")
  if not file then
    logger:debug (translate ("write-failure", {
      filename = filename,
      message  = err,
    }))
  else
     logger:debug (translate ("write-success", {
      filename = filename,
      message  = err,
    }))
    file:write ("1..%{n}\n" % {n = #tests })
    for i = 1, #tests do
      local test = tests [i]
      if test.success then
        file:write ("ok %{id} - %{filename}:%{from}--%{to}\n" % test)
      else
        file:write ("not ok %{id} - %{filename}:%{from}--%{to}\n" % test)
        local message = test.message
        message = message:gsub ("^", "    ")
        file:write (message .. "\n")
      end
    end
  end
  logger:info (translate ("tap-done", {
    filename  = filename,
  }))
end

do
  local successes = 0
  local failures  = 0
  for i = 1, #tests do
    local test = tests [i]
    if test.success then
      successes = successes + 1
    else
      failures = failures + 1
    end
  end
  logger:info (translate ("summary", {
    filename  = filename,
    total     = #tests,
    successes = successes,
    failures  = failures,
  }))
end
