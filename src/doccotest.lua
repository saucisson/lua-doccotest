local DoccoTest = {}

DoccoTest.__index = DoccoTest

local i18n       = require "i18n"
local colors     = require "ansicolors"
local rings      = require "rings"
local logging    = require "logging"
logging.console  = require "logging.console"

local string_metatable = getmetatable ""
string_metatable.__mod = require "i18n.interpolate"

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

--    > local x = 1


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
              self.logger:debug (self:translate ("no-prompt", {
                filename = filename,
                from     = session.from - 1,
                to       = session.from - 1,
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
__TEST__  = true
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
  if type (err) ~= "table" then
    err = tostring (err)
  else
    local serpent = require "serpent"
    err = serpent.line (err, {
      sortkeys = true,
      compact  = true,
      fatal    = false,
      nocode   = true,
      comment  = false,
    })
  end
  io.stdout:write ("error: " .. err)
else
  res, err = pcall (res)
  if not res then
    if type (err) ~= "table" then
      err = tostring (err)
    else
      local serpent = require "serpent"
      err = serpent.line (err, {
        sortkeys = true,
        compact  = true,
        fatal    = false,
        nocode   = true,
        comment  = false,
      })
    end
    io.stdout:write ("error: " .. err)
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
            self.logger:debug (self:translate ("chunk-success", {
              filename = filename,
              from     = session.from + from - 1,
              to       = session.from + to   - 1,
            }))
          else
            self.logger:warn (self:translate ("chunk-failure", {
              filename = filename,
              from     = session.from + from - 1,
              to       = session.from + to   - 1,
              message  = err,
            }))
          end
          local patterns = {}
          for i = 1, #result do
            local line = result [i]
            line = line:gsub ("%(%.%.%.%)%s*$", "")
            -- http://lua-users.org/wiki/StringTrim (trim6)
            line = line:match "^()%s*$" and "" or line:match "^%s*(.*%S)"
            local is_wildcard = line:match "%.%.%."
            if line ~= "" then
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
              if not is_wildcard then
                line = line .. "[\r\n]*"
              end
              patterns [i] = line
            end
          end
          local pattern = "^" .. table.concat (patterns) .. "$"
          if stdout:match (pattern) then
            self.logger:info (self:translate ("test-success", {
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
            self.logger:info (self:translate ("test-failure", {
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
          self.logger:debug (self:translate ("ring-keep", {
            filename = filename,
            from     = session.from,
            to       = session.to,
          }))
        else
          ring:close ()
          ring = nil
          self.logger:debug (self:translate ("ring-close", {
            filename = filename,
            from     = session.from,
            to       = session.to,
          }))
        end
      end
      file:close ()
    end
  end
end

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
