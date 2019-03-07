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
      inputs              paths to source code files

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

For instance, try running:

    $ doccotest --verbose example.lua

Writing Tests
-------------

The code to test is prefixed by at least four spaces and ">",
and the expected answer is put below.
Here, `return 1` is tested, and the result `1` is expected:

    --    > return 1
    --    1

Of course, other data types can be used, for instance:

    --    > return "a"
    --    "a"
    --    > return true
    --    true
    --    > return { b = 1, a = 2 }
    --    { a = 2, b = 1 }

Local variables can be defined within a code block:

    --    > local a = 1
    --    > local b = 2*a
    --    > return b
    --    2

But local variables disappear at the beginning of each code block:

    --    > return a
    --    nil

Global variables, on the contrary, live outside code blocks:

    --    > c = 4
    --    > return c
    --    4
    --    > return c
    --    4

The `reset` command resets the environment,
and thus unset global variables:

    --    /reset
    --    > return c
    --    nil

It is possible to store a result in a (global) variable:

    --    > return 1
    --    _.a

And even to extract a value from a table into a global variable:

    --    > return { b = 2 }
    --    { b = _.b }

These global variables can be used as any other variable:

    --    > return a, b
    --    1, 2

Variables that have been matched can be used also in expectations:
    --    > return a + 1
    --    b

It is possible to use the current module in tests,
by `require`ing it and using it within tests:

    --    > local f = require "example"
    --    > return f (2)
    --    4
    -- And the definition of the "example" module is:
    local function f(x) return x*x end
    return f
