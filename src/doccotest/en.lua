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
      "!{white redbg}Output format %{format} is not recognized.",
    ["read:success"       ] =
      "Input file %{filename} opened for reading.",
    ["read:failure"       ] =
      "!{white redbg}Cannot open input file %{filename}, because: %{message}.",
    ["write:success"      ] =
      "Output file %{filename} opened for writing.",
    ["write:failure"      ] =
      "!{white redbg}Cannot open output file %{filename}, because: %{message}.",
    ["chunk:success"      ] =
      "!{green}%{filename}:%{from}--%{to}: chunk has succeeded.",
    ["chunk:failure"      ] =
      "!{red}%{filename}:%{from}--%{to}: chunk has failed, because: %{message}.",
    ["command:reset"    ] =
      "!{white bluebg}%{filename}:%{line}: state has been reset.",
    ["command:unknown"    ] =
      "!{white redbg}%{filename}:%{line}: unknown command %{command}.",
    ["test:success"       ] =
      "!{green}%{filename}:%{from}--%{to}: test has succeeded.",
    ["test:failure"       ] =
      "!{red}%{filename}:%{from}--%{to}: test has failed, obtained %{error}%{result}.",
    ["result:missing"     ] =
      "!{yellow}%{filename}:%{from}--%{to} does not refer to any test.",
    ["expectation:illegal"] =
      "!{red}%{filename}:%{from}--%{to} is illegal: illegal expectation, because %{message}.",
    ["tap:done"           ] =
      "TAP report has been output in !{bluebg white}%{filename}!{reset}.",
    ["summary"            ] =
      "%{filename}: !{green}%{successes}!{reset} success / !{red}%{failures}!{reset} failure / !{yellow}%{total}!{reset} total.",
  }
}
