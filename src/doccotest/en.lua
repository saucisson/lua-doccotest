return {
  en = {
    ["input-help"    ] = "path to the source code file",
    ["inputs-help"   ] = "paths to other source code files",
    ["output-help"   ] = "path to the output file",
    ["format-help"   ] = "output format: TAP",
    ["verbose-help"  ] = "enable verbose mode",
    ["unknown-format"] = "!{white redbg}Output format %{format} is not recognized.",
    ["read-success"  ] = "Input file %{filename} opened for reading.",
    ["read-failure"  ] = "!{white redbg}Cannot open input file %{filename}, because: %{message}.",
    ["write-success" ] = "Output file %{filename} opened for writing.",
    ["write-failure" ] = "!{white redbg}Cannot open output file %{filename}, because: %{message}.",
    ["no-prompt"     ] = "Chunk at %{filename}:%{from}--%{to} does not start with a prompt.",
    ["chunk-success" ] = "Execution of chunk at %{filename}:%{from}--%{to} is successful.",
    ["chunk-failure" ] = "Execution of chunk at %{filename}:%{from}--%{to} failed, because: %{message}.",
    ["ring-keep"     ] = "Keeping ring after chunk at %{filename}:%{from}--%{to}.",
    ["ring-close"    ] = "Closed ring after chunk at %{filename}:%{from}--%{to}.",
    ["test-success"  ] = "!{green}Test passed at %{filename}:%{from}--%{to}.",
    ["test-failure"  ] = "!{red}Test failed at %{filename}:%{from}--%{to}: %{stdout}.",
    ["tap-done"      ] = "TAP output done in %{filename}.",
    ["summary"       ] = "%{filename}: !{green}%{successes}!{reset} success / !{red}%{failures}!{reset} failure / !{yellow}%{total}!{reset} total.",
  }
}