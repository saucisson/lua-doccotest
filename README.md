Doctest for Lua commented with Docco
====================================

The `doccotest` tool is a port of
[Python's `doctest`](https://docs.python.org/2/library/doctest.html) to the
[Lua programming language](http://www.lua.org/).
It runs tests defined within code comments and compares their
output with a reference one, given also within code comments.

`doccotest` is designed to work on source code written in
[Lua](http://www.lua.org/), and commented in
[markdown](http://daringfireball.net/projects/markdown/).
The documentation for the code can be generated using
[docco](http://jashkenas.github.io/docco/) or
[locco](http://rgieseke.github.io/locco/), and embeds the tests and their
expected results.

Install
-------

This tool is easily installed using [LuaRocks](https://rocks.moonscript.org/):

    $ luarocks install doccotest

Run
---

The `doccotest` tool is composed of a library and a runnable script.
Please ensure that the library is in your `LUA_PATH` and the script is in your
`PATH`. The [LuaRocks](https://rocks.moonscript.org/) installation
does the job for you.

Running the command without arguments shows the help message:

    $ doccotest
    error: bad number of arguments: 1-1000 argument(s) must be specified, not 0;
    re-run with --help for usage.
    Usage: ../bin/doccotest [OPTIONS]  input  [inputs-1 [inputs-2 [...]]]
    
    ARGUMENTS: 
      input               path to the source code file (required)
      inputs              paths to other source code files
                          (optional, default: )
    
    OPTIONS: 
      --output=<filename> path to the output file (default:
                          test-results.txt)
      --format=<format>   output format: nothing or TAP (default:
                          none)
      -v, --verbose       enable verbose mode


The `input(s)` files are the [Lua](http://www.lua.org/) source that contain the
tests. The `output` file is used to generate a report. A report is only
generated when its format is specified. The only supported format (currently)
is the [TAP](https://testanything.org/) format.

Writing Tests
-------------

