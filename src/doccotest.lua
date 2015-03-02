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

function string:quote ()
  if not (self:find "\n" or self:find "\r") then
    if not self:find ('"') then
      return '"' .. self .. '"'
    elseif not self:find ("'") then
      return "'" .. self .. "'"
    end
  end
  local pattern = ""
  while true do
    if not (   self:find ("%[" .. pattern .. "%[")
            or self:find ("%]" .. pattern .. "%]")) then
      return "[" .. pattern .. "[" .. self .. "]" .. pattern .. "]"
    end
    pattern = pattern .. "="
  end
end

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

function DoccoTest:translate (string, t)
  assert (type (string) == "string")
  assert (t == nil or type (t) == "table")
  t = t or {}
  t.locale = self.locale
  string = i18n (string, t)
  string = string:gsub ("!{", "%%{")
  string = colors (string)
  return string
end

local read_pattern  = "%?{([_%a][_%w]*)}"
local write_pattern = "%!{([_%a][_%w]*)}"
local test_pattern  = [[
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
if not success and type (result) ~= "table" then
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

local function compare (lhs, rhs)
  if type (lhs) ~= type (rhs) then
    return false
  end
  if type (lhs) ~= "table" then
    return lhs == rhs
  end
  for k in pairs (lhs) do
    local l = lhs [k]
    local r = rhs [k]
    local result = compare (l, r)
    if not result then
      return false
    end
  end
  return true
end

function DoccoTest:test (filenames)
  assert (type (filenames) == "table")
  self.tests = {}
  for i = 1, #filenames do
    local filename  = filenames [i]
    local file, err = io.open (filename, "r")
    if not file then
      self.logger:error (self:translate ("read-failure", {
        filename = filename,
        message  = err,
      }))
    else
      self.logger:debug (self:translate ("read-success", {
        filename = filename,
      }))
      local tests = {
        filename = filename,
      }
      self.tests [#self.tests+1] = tests
      local line_number = 0
      local from
      local to
      local code
      local expectation
      local result
      local ring        = rings.new ()
      local variables   = {}
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
          local test    = test_pattern % { code = code:quote () }
          code = nil
          local ok, res = ring:dostring (test)
          if ok then
            result = res
            tests [#tests+1] = {
              success  = true,
              filename = filename,
              from     = from,
              to       = to,
            }
            self.logger:info (self:translate ("chunk:success", tests [#tests]))
          else
            result = nil
            local _, stderr = ring:dostring [[
              io.stderr:seek "set"
              return io.stderr:read "*all"
            ]]
            tests [#tests+1] = {
              success  = false,
              filename = filename,
              from     = from,
              to       = to,
              message  = stderr,
            }
            self.logger:warn (self:translate ("chunk:failure", tests [#tests]))
          end
        elseif expectation and not cexpectation then
          to = line_number - 1
          if result == nil then
            tests [#tests+1] = {
              success  = false,
              filename = filename,
              from     = from,
              to       = to,
            }
            self.logger:warn (self:translate ("result:missing", tests [#tests]))
          else
            local should_succeed = not expectation:match "^%s*error%s*:%s*(.*)$"
            if not should_succeed then
              expectation = expectation:match "^%s*error%s*:%s*(.*)$"
            end
            local expected, err = loadstring ("return " .. expectation)
            if not expected then
              self.logger:warn (self:translate ("expectation:illegal", {
                filename = filename,
                from     = from,
                to       = to,
                message  = err,
              }))
            else
              expected = {
                success = should_succeed,
                result  = expected (),
              }
              local obtained = loadstring ("return " .. result) ()
              tests [#tests+1] = {
                success  = compare (expected, obtained),
                filename = filename,
                from     = from,
                to       = to,
                error    = obtained.success and "" or "error: ",
                result   = serpent.line (obtained.result, {
                  sortkeys = true,
                  compact  = true,
                  fatal    = false,
                  nocode   = true,
                  comment  = false,
                }),
              }
              if tests [#tests].success then
                self.logger:info (self:translate ("test:success", tests [#tests]))
              else
                self.logger:warn (self:translate ("test:failure", tests [#tests]))
              end
            end
          end
          expectation = nil
        end
        if ccommand == "reset" then
          self.logger:info (self:translate ("command:reset", {
            filename = filename,
            line     = line_number,
            command  = ccommand,
          }))
          ring        = rings.new ()
          variables   = {}
          code        = nil
          expectation = nil
          result      = nil
        elseif ccommand ~= nil then
          self.logger:warn (self:translate ("command:unknown", {
            filename = filename,
            line     = line_number,
            command  = ccommand,
          }))
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

--    > = "x"
--    "x"

--    > = "x"
--    "y"

--    > = error "x"
--    "y"

--    > = a b c

--    /reset

function DoccoTest:tap (filename)
  local file, err = io.open (filename, "w")
  if not file then
    self.logger:debug (self:translate ("write-failure", {
      filename = filename,
      message  = err,
    }))
  else
    self.logger:debug (self:translate ("write-success", {
      filename = filename,
      message  = err,
    }))
    local count = 0
    for _, tests in ipairs (self.tests) do
      count = count + #tests
    end
    file:write ("1..%{n}\n" % { n = count })
    for _, tests in ipairs (self.tests) do
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
  end
  self.logger:debug (self:translate ("tap-done", {
    filename  = filename,
  }))
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
    self.logger:info (self:translate ("summary", {
      filename  = tests.filename,
      total     = #tests,
      successes = successes,
      failures  = failures,
    }))
    all_tests     = all_tests     + #tests
    all_successes = all_successes + successes
    all_failures  = all_failures  + failures
  end
  self.logger:info (self:translate ("summary", {
    filename  = "all",
    total     = all_tests,
    successes = all_successes,
    failures  = all_failures,
  }))
end

return DoccoTest
