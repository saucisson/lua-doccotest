local DoccoTest = {}

DoccoTest.__index = DoccoTest

local string_metatable = getmetatable ""
string_metatable.__mod = function (pattern, variables)
  variables = variables or {}
  return pattern:gsub ("(.?)%%{(%w+)}", function (previous, key)
    if previous == "%" then
      return
    end
    local value = tostring (variables [key])
    return previous .. value
  end)
end
package.preload ["i18n.interpolate"] = function ()
  return string_metatable.__mod
end

local i18n       = require "i18n"
local colors     = require "ansicolors"
local rings      = require "rings"
local serpent    = require "serpent"
local logging    = require "logging"

local logger     = logging.new (function (_, level, message)
  local reset = colors ""
  if     level == logging.DEBUG then
    print (colors.noReset "%{cyan}" .. message .. reset)
  elseif level == logging.INFO then
    print (colors.noReset "%{green}" .. message .. reset)
  elseif level == logging.WARN then
    print (colors.noReset "%{red}" .. message .. reset)
  elseif level == logging.ERROR then
    print (colors.noReset "%{red whitebg}" .. message .. reset)
  elseif level == logging.FATAL then
    print (colors.noReset "%{blink red whitebg}" .. message .. reset)
  end
  return true
end)

-- http://lua-users.org/wiki/StringTrim (trim6)
function _G.string:trim ()
  return self:match "^()%s*$" and "" or self:match "^%s*(.*%S)"
end

function DoccoTest.new ()
  local result = setmetatable ({
    logger = logger,
  }, DoccoTest)
  result:localize ()
  return result
end

function DoccoTest:localize ()
  i18n.load (require "doccotest.en")
  i18n.setLocale "en"
  local language, variant = (os.getenv "LANG"):match "^(%l+)_(%u+)"
  self.locale = "%{language}-%{variant}" % {
    language = language,
    variant  = variant,
  }
  do
    local ok, locale = pcall (require, "doccotest.%{language}" % {
      language = language,
    })
    if ok then i18n.load (locale) end
  end
  do
    local ok, locale = pcall (require, "doccotest.%{language}_%{variant}" % {
      language = language,
      variant  = variant,
    })
    if ok then i18n.load (locale) end
  end
end

function DoccoTest:translate (t)
  t.locale = self.locale
  return i18n (t._, t)
end

function DoccoTest.load (_, s)
  local ring = rings.new ()
  local ok, result = ring:dostring (s)
  if not ok then
    return nil, result
  end
  return serpent.load (result, {
    safe = true,
  })
end

function DoccoTest.quote (_, s)
  return serpent.line (s, {
    sortkeys = true,
    compact  = true,
    fatal    = false,
    nocode   = true,
    comment  = false,
  })
end

function DoccoTest.dump (_, s)
  return serpent.line (s, {
    sortkeys = true,
    compact  = true,
    fatal    = false,
    nocode   = true,
    comment  = false,
  })
end

local test_pattern  = [[
local function traceback ()
  local traces = {}
  local level  = 3
  repeat
    local info = debug.getinfo (level, "nlS")
    traces [#traces+1] = info
    level = level+1
  until not info
  traces [#traces] = nil
  traces [#traces] = nil
  return traces
end
local environment = %{environment}
for k, v in pairs (environment) do
  _G [k] = v
end
local code = %{code}
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
__TEST__  = true
io.stdout = io.tmpfile ()
io.stderr = io.tmpfile ()
io.output (io.stdout)
pcall (require, "luacov")
local serpent = require "serpent"
local chunk, err = loadstring (code)
if not chunk then
  io.stderr:write (err)
  error (err)
end
local error, trace
local results = { xpcall (chunk, function (err)
  if type (err) == "string" then
    error = err:match ".*:%s*(.*)"
  else
    error = err
  end
  trace = traceback ()
end) }
local success = results [1]
table.remove (results, 1)
if not success then
  results = error
end
return serpent.line ({
  success = success,
  result  = results,
  trace   = trace,
}, {
  sortkeys = true,
  compact  = true,
  fatal    = false,
  nocode   = true,
  comment  = false,
})
]]

local expectation_pattern = [[
local serpent = require "serpent"
local environment = %{environment}
for k, v in pairs (environment) do
  _G [k] = v
end
_G._ = setmetatable ({}, {
  __index = function (self, key)
    return { __doccotest__variable__ = key }
  end,
})
local function f (...)
  return serpent.line (%{expectation}, {
    sortkeys = true,
    compact  = true,
    fatal    = false,
    nocode   = true,
    comment  = false,
  })
end
return f "__doccotest__wildcard__"
]]

local result_pattern = [[
local serpent = require "serpent"
local environment = %{environment}
for k, v in pairs (environment) do
  _G [k] = v
end
return serpent.line (%{result}, {
  sortkeys = true,
  compact  = true,
  fatal    = false,
  nocode   = true,
  comment  = false,
})
]]

function DoccoTest:compare (lhs, rhs)
  if type (lhs) == "table" and lhs.__doccotest__variable__ then
    return true
  end
  if type (lhs) ~= type (rhs)
  and lhs ~= "__doccotest__wildcard__"
  and rhs ~= "__doccotest__wildcard__" then
    return false
  end
  if type (lhs) ~= "table" then
    return lhs == rhs
        or lhs == "__doccotest__wildcard__"
        or rhs == "__doccotest__wildcard__"
  end
  local lhs_wildcard = false
  for _, v in pairs (lhs) do
    if v == "__doccotest__wildcard__" then
      lhs_wildcard = true
    end
  end
  local rhs_wildcard = false
  for _, v in pairs (rhs) do
    if v == "__doccotest__wildcard__" then
      rhs_wildcard = true
    end
  end
  local seen = {}
  for k in pairs (lhs) do
    seen [k] = true
    local l = lhs [k]
    local r = rhs [k]
    if r == nil and not rhs_wildcard then
      return false
    end
    local result = self:compare (l, r)
    if not result then
      return false
    end
  end
  for k in pairs (rhs) do
    if not seen [k] then
      local l = lhs [k]
      local r = rhs [k]
      if l == nil and not lhs_wildcard then
        return false
      end
      local result = self:compare (l, r)
      if not result then
        return false
      end
    end
  end
  return true
end

function DoccoTest:fill_environment (lhs, rhs)
  if type (lhs) == "table" then
    if lhs.__doccotest__variable__ then
      self.variables [lhs.__doccotest__variable__] = rhs
    else
      for k in pairs (lhs) do
        local l = lhs [k]
        local r = rhs [k]
        self:fill_environment (l, r)
      end
    end
  end
end

function DoccoTest:test (filenames)
  assert (type (filenames) == "table")
  self.tests = {}
  for i = 1, #filenames do
    local filename  = filenames [i]
    local file, err = io.open (filename, "r")
    if not file then
      self.logger:error (self:translate {
        _        = "read:failure",
        filename = filename,
        message  = err,
      })
    else
      self.logger:debug (self:translate {
        _        = "read:success",
        filename = filename,
      })
      local line_prefix
      if loadfile (filename) then
        line_prefix = "%-%-"
        self.logger:debug (self:translate {
          _        = "lua:success",
          filename = filename,
        })
      else
        line_prefix = ""
        self.logger:debug (self:translate {
          _        = "lua:failure",
          filename = filename,
        })
      end
      local nb_lines = 0
      for _ in file:lines () do
        nb_lines = nb_lines+1
      end
      file = io.open (filename, "r")
      local tests = {
        filename = filename,
      }
      self.tests [#self.tests+1] = tests
      self.ring      = rings.new ()
      self.variables = {}
      local from
      local to
      local code
      local expectation
      local result
      local lineof_pattern = "%0%{size}d" % {
        size = math.ceil (math.log10 (nb_lines+1))
      }
      local function lineof (n)
        return string.format (lineof_pattern, n)
      end
      for line_number = 1, nb_lines+1 do
        local line = file:read "*l" or ""
        local ccode        =
             line:match ("^%s*" .. line_prefix .. "    %s*>%s*(.*)$")
          or line:match ("^%s*" .. line_prefix .. "%t%s*>%s*(.*)$")
        local ccommand     =
             line:match ("^%s*" .. line_prefix .. "    %s*/([_%a][_%w]*)%s*$")
          or line:match ("^%s*" .. line_prefix .. "%t%s*/([_%a][_%w]*)%s*$")
        local cexpectation =
             line:match ("^%s*" .. line_prefix .. "    %s*([^/>].*)$")
          or line:match ("^%s*" .. line_prefix .. "%t%s*([^/>].*)$")
        ccommand     = ccommand     and ccommand    :trim () or nil
        ccode        = ccode        and ccode       :trim () or nil
        cexpectation = cexpectation and cexpectation:trim () or nil
        if code and not ccode then
          to = line_number - 1
          local test    = test_pattern % {
            environment = self:dump  (self.variables),
            code        = self:quote (code),
            position    = self:quote (self:translate {
              _        = "chunk:position",
              filename = filename,
              from     = lineof (from),
              to       = lineof (to),
            }),
          }
          code     = nil
          local ok, res = self.ring:dostring (test)
          if ok then
            result      = res
            expectation = ""
            self.logger:debug (self:translate {
              _        = "chunk:success",
              success  = true,
              filename = filename,
              from     = lineof (from),
              to       = lineof (to),
            })
          else
            result = nil
            local _, stderr = self.ring:dostring [[
              io.stderr:seek "set"
              return io.stderr:read "*all"
            ]]
            tests [#tests+1] = {
              _        = "chunk:failure",
              success  = false,
              filename = filename,
              from     = lineof (from),
              to       = lineof (to),
              message  = stderr,
            }
            self.logger:warn (self:translate (tests [#tests]))
          end
        elseif expectation and not cexpectation then
          to = line_number - 1
          if not from then
            from = to
          end
          if expectation == "" then
            expectation = "nil"
          else
            expectation = "{ %{expectation} }" % {
              expectation = expectation,
            }
          end
          if result == nil then
            self.logger:warn (self:translate {
              _        = "result:missing",
              success  = false,
              filename = filename,
              from     = lineof (from),
              to       = lineof (to),
            })
          else
            local should_succeed = not expectation:match "^%s*error%s*:%s*(.*)$"
            if not should_succeed then
              expectation = expectation:match "^%s*error%s*:%s*(.*)$"
            end
            local ok, expected = self:load (expectation_pattern % {
              environment = self:dump (self.variables),
              expectation = expectation,
            })
            if not ok then
              self.logger:warn (self:translate {
                _        = "expectation:illegal",
                filename = filename,
                from     = lineof (from),
                to       = lineof (to),
                message  = expected,
              })
            else
              if expected == nil then
                expected = {}
              end
              expected = {
                success = should_succeed,
                result  = expected,
              }
              if not expected.success then
                expected.trace = "__doccotest__wildcard__"
              end
              local _, obtained = self:load (result_pattern % {
                environment = "{}",
                result      = result,
              })
              tests [#tests+1] = {
                success  = self:compare (expected, obtained),
                filename = filename,
                from     = lineof (from),
                to       = lineof (to),
              }
              if tests [#tests].success then
                self:fill_environment (expected, obtained)
                tests [#tests]._ = "test:success"
                self.logger:info (self:translate (tests [#tests]))
              elseif obtained.success then
                tests [#tests].result = self:dump (obtained.result)
                tests [#tests].trace  = ""
                tests [#tests]._      = "test:failure"
                self.logger:warn (self:translate (tests [#tests]))
              elseif not obtained.success then
                local trace = {}
                for z = 1, #obtained.trace do
                  local info = obtained.trace [z]
                  if     info.what == "C" then
                    trace [#trace+1] = "    in %{source}: %{what} %{name}" % {
                      source = info.source:sub (2),
                      what   = "function",
                      name   = info.name,
                    }
                  elseif info.what == "Lua" then
                    trace [#trace+1] = "    in %{source}:%{line} %{what} %{name}" % {
                      source = info.source:sub (2),
                      what   = info.namewhat,
                      name   = info.name,
                      line   = info.currentline,
                    }
                  elseif info.what == "main" then
                    trace [#trace+1] = "    in %{filename}:%{line}" % {
                      filename = filename,
                      line     = from + info.currentline -1,
                    }
                  end
                end
                tests [#tests].result = "error: " .. self:dump (obtained.result)
                tests [#tests].trace  = table.concat (trace, "\n")
                tests [#tests]._      = "test:failure"
                self.logger:warn (self:translate (tests [#tests]))
              end
            end
          end
          expectation = nil
        end
        if ccommand == "reset" then
          self.logger:info (self:translate {
            _        = "command:reset",
            filename = filename,
            line     = lineof (line_number),
            command  = ccommand,
          })
          self.ring      = rings.new ()
          self.variables = {}
          code           = nil
          expectation    = nil
          result         = nil
        elseif ccommand ~= nil then
          self.logger:warn (self:translate {
            _        = "command:unknown",
            filename = filename,
            line     = lineof (line_number),
            command  = ccommand,
          })
        elseif ccode ~= nil then
          ccode = ccode:gsub ("^%s*(=)", "return ")
          if code == nil then
            code = ccode
            from = line_number
          else
            code = code .. "\n" .. ccode
          end
        elseif cexpectation ~= nil then
          if expectation == nil then
            expectation = cexpectation
            from        = line_number
          else
            expectation = expectation .. "\n" .. cexpectation
          end
        end
      end
    end
    file:close ()
  end
end

function DoccoTest:tap (filename)
  local file, err = io.open (filename, "w")
  if not file then
    self.logger:debug (self:translate {
      _        = "write:failure",
      filename = filename,
      message  = err,
    })
  else
    self.logger:debug (self:translate {
      _        = "write:success",
      filename = filename,
      message  = err,
    })
    local count = 0
    for _, tests in ipairs (self.tests) do
      count = count + #tests
    end
    file:write ("1..%{n}\n" % { n = count })
    for _, tests in ipairs (self.tests) do
      for i = 1, #tests do
        local test   = tests [i]
        test.id      = i
        test.message = self:translate (test)
        if test.success then
          file:write ("ok %{id} - %{filename}:%{from}--%{to}\n" % test)
        else
          file:write ("not ok %{id} - %{filename}:%{from}--%{to}\n" % test)
        end
        file:write ("    " .. test.message .. "\n")
      end
    end
  end
  self.logger:info (self:translate {
    _        = "tap:done",
    filename = filename,
  })
end

function DoccoTest:summary ()
  assert (self.tests)
  local all_tests     = 0
  local all_successes = 0
  local all_failures  = 0
  for _, tests in ipairs (self.tests) do
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
    print (self:translate {
      _        = "summary",
      filename = tests.filename,
      total    = colors ("%{yellow}" .. tostring (#tests)),
      success  = colors ("%{green}"  .. tostring (successes)),
      failure  = colors ("%{red}"    .. tostring (failures)),
    })
    all_tests     = all_tests     + #tests
    all_successes = all_successes + successes
    all_failures  = all_failures  + failures
  end
  print (self:translate {
    _        = "summary",
    filename = "Overall summary",
    total    = colors ("%{yellow}" .. tostring (all_tests)),
    success  = colors ("%{green}"  .. tostring (all_successes)),
    failure  = colors ("%{red}"    .. tostring (all_failures)),
  })
end

return DoccoTest
