local DoccoTest = {}

DoccoTest.__index = DoccoTest

local i18n       = require "i18n"
local colors     = require "ansicolors"
local rings      = require "rings"
local serpent    = require "serpent"
local logging    = require "logging"
logging.console  = require "logging.console"

local string_metatable = getmetatable ""
string_metatable.__mod = require "i18n.interpolate"

-- http://lua-users.org/wiki/StringTrim (trim6)
function string:trim ()
  return self:match "^()%s*$" and "" or self:match "^%s*(.*%S)"
end

function DoccoTest.new ()
  local result = setmetatable ({
    logger    = logging.console "%message\n",
  }, DoccoTest)
  result:localize ()
  return result
end

function DoccoTest:localize ()
  i18n.load (require "doccotest.en")
  i18n.setLocale "en"
  local locale = os.getenv "LANG"
  local language, variant = locale:match "^(%l+)_(%u+)"
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
  string = i18n (t._, t)
  string = string:gsub ("!{", "%%{")
  string = colors (string)
  return string
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
local success, result = pcall (chunk)
if not success and type (result) == "string" then
  result = result:match (": (.*)")
end
return serpent.line ({
  success = success,
  result  = result,
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
    return { __doccotest__var__ = key }
  end,
})
return serpent.line (%{expectation}, {
  sortkeys = true,
  compact  = true,
  fatal    = false,
  nocode   = true,
  comment  = false,
})
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
  if type (lhs) == "table" and lhs.__doccotest__var__ then
    return true
  end
  if type (lhs) ~= type (rhs) then
    return false
  end
  if type (lhs) ~= "table" then
    return lhs == rhs
  end
  for k in pairs (lhs) do
    local l = lhs [k]
    local r = rhs [k]
    local result = self:compare (l, r)
    if not result then
      return false
    end
  end
  return true
end

function DoccoTest:fill_environment (lhs, rhs)
  if type (lhs) == "table" then
    if lhs.__doccotest__var__ then
      self.variables [lhs.__doccotest__var__] = rhs
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
      self.logger:warn (self:translate {
        _        = "read:failure",
        filename = filename,
        message  = err,
      })
    else
      self.logger:debug (self:translate {
        _        = "read:success",
        filename = filename,
      })
      local tests = {
        filename = filename,
      }
      self.tests [#self.tests+1] = tests
      self.ring      = rings.new ()
      self.variables = {}
      local line_number = 0
      local from
      local to
      local code
      local expectation
      local result
      for line in file:lines () do
        line_number = line_number + 1
        local ccode        = line
                             :match "^%s*%-%-    %s*>%s*(.*)$"
                          or line
                             :match "^%s*%-%-%t%s*>%s*(.*)$"
        local ccommand     = line
                             :match "^%s*%-%-    %s*/([_%a][_%w]*)%s*$"
                          or line
                             :match "^%s*%-%-%t%s*/([_%a][_%w]*)%s*$"
        local cexpectation = line
                             :match "^%s*%-%-    %s*([^/>].*)$"
                          or line
                             :match "^%s*%-%-%t%s*([^/>].*)$"
        ccommand     = ccommand     and ccommand    :trim () or nil
        ccode        = ccode        and ccode       :trim () or nil
        cexpectation = cexpectation and cexpectation:trim () or nil
        if code and not ccode then
          to = line_number - 1
          local test    = test_pattern % {
            environment = self:dump  (self.variables),
            code        = self:quote (code), 
          }
          code = nil
          local ok, res = self.ring:dostring (test)
          if ok then
            result      = res
            expectation = ""
            tests [#tests+1] = {
              _        = "chunk:success",
              success  = true,
              filename = filename,
              from     = from,
              to       = to,
            }
            self.logger:info (self:translate (tests [#tests]))
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
              from     = from,
              to       = to,
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
          end
          if result == nil then
            self.logger:warn (self:translate {
              _        = "result:missing",
              success  = false,
              filename = filename,
              from     = from,
              to       = to,
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
                from     = from,
                to       = to,
                message  = expected,
              })
            else
              expected = {
                success = should_succeed,
                result  = expected,
              }
              local _, obtained = self:load (result_pattern % {
                environment = "{}",
                result      = result,
              })
              tests [#tests+1] = {
                success  = self:compare (expected, obtained),
                filename = filename,
                from     = from,
                to       = to,
                error    = obtained.success and "" or "error: ",
                result   = self:dump (obtained.result),
              }
              if tests [#tests].success then
                self:fill_environment (expected, obtained)
                tests [#tests]._ = "test:success"
                self.logger:info (self:translate (tests [#tests]))
              else
                tests [#tests]._ = "test:failure"
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
            line     = line_number,
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
            line     = line_number,
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
    self.logger:info (self:translate {
      _         = "summary",
      filename  = tests.filename,
      total     = #tests,
      successes = successes,
      failures  = failures,
    })
    all_tests     = all_tests     + #tests
    all_successes = all_successes + successes
    all_failures  = all_failures  + failures
  end
  self.logger:info (self:translate {
    _         = "summary",
    filename  = "all",
    total     = all_tests,
    successes = all_successes,
    failures  = all_failures,
  })
end

return DoccoTest
