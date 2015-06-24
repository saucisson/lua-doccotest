return {
  en = {
    ["input:help"         ] =
      "path to the source code file",
    ["inputs:help"        ] =
      "paths to other source code files",
    ["output:help"        ] =
      "path to the output file",
    ["format:help"        ] =
      "output format: none or TAP",
    ["verbose:help"       ] =
      "enable verbose mode",
    ["format:unknown"     ] =
      "Output format %{format} is not recognized.",
    ["read:success"       ] =
      "Input file %{filename} opened for reading.",
    ["read:failure"       ] =
      "Cannot open input file %{filename}, because: %{message}.",
    ["lua:success"       ] =
      "Input file %{filename} is considered as Lua.",
    ["lua:failure"       ] =
      "Input file %{filename} is not considered as Lua.",
    ["write:success"      ] =
      "Output file %{filename} opened for writing.",
    ["write:failure"      ] =
      "Cannot open output file %{filename}, because: %{message}.",
    ["chunk:success"      ] =
      "%{filename}:%{from}--%{to}: chunk has been run.",
    ["chunk:failure"      ] =
      "%{filename}:%{from}--%{to}: chunk has not been run, because: %{message}.",
    ["command:reset"      ] =
      "%{filename}:%{line}: state has been reset.",
    ["command:unknown"    ] =
      "%{filename}:%{line}: unknown command %{command}.",
    ["chunk:position"     ] =
      "In code snippet at %{filename}:%{from}--%{to}:",
    ["test:success"       ] =
      "%{filename}:%{from}--%{to}: test has succeeded.",
    ["test:failure"       ] =
      "%{filename}:%{from}--%{to}: test has failed\n  %{result}\n%{trace}.",
    ["result:missing"     ] =
      "%{filename}:%{from}--%{to} does not refer to any test.",
    ["expectation:illegal"] =
      "%{filename}:%{from}--%{to} is illegal: illegal expectation, because %{message}.",
    ["tap:done"           ] =
      "TAP report has been output in %{filename}.",
    ["summary"            ] =
      "%{filename}: %{success} success / %{failure} failure / %{total} total.",
  }
}
