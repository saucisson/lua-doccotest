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
`PATH`. The [LuaRocks](https://rocks.moonscript.org/) installation should
ensure these constraints.

Running the command without arguments shows the help message:

    $ doccotest
    doccotest: error: bad number of arguments: 1-2 argument(s) must be
    specified, not 0; re-run with --help for usage.
    Usage: doccotest [OPTIONS]  input  [inputs]

    ARGUMENTS: 
      input               path to the source code file (required)
      inputs              paths to other source code files
                          (optional, default: )

    OPTIONS: 
      --output=<filename> path to the output file (default:
                          test-results.txt)
      --format=<format>   output format: TAP (default: TAP)
      -v, --verbose       enable verbose mode

The `input(s)` files are the [Lua](http://www.lua.org/) source that contain the
tests. The `output` file is used to generate a report in
[TAP](https://testanything.org/) format (currently the only one supported).

Writing Tests
-------------

A test is defined in a code listing followed by the expected output,
all within a Lua comment.
The comment must be on a line starting with `--`, not within a comment block.
The listing within comment is defined by at least 4 spaces after `--`.
The first line must start with a prompt `> ` (do not forget the space!),
whereas the remaining lines must start with `>> ` (do not forget the space!).
At the end come the output lines, that contain the expected **output** of the above
instructions.

    --    > local x = 1
    --    >> print (x)
    --    1

Sometimes, a part of the output is irrelevant. You can use `...` as a wildcard.

    --    > local x = 1
    --    >> print "some irrelevant stuff"
    --    >> print ("something", x, "something")
    --    >> print "some even less relevant stuff"
    --    ...
    --    1
    --    ...

The environment is reinitialized between each test, so local and global
variables are lost. This can be a pain for imported modules, for instance.

    --    > x = 1
    
    --    > print (x)
    --    nil

To keep all global variables, put a `(...)` in the last line of the output.
Note that there is no way to pass local variables from one test to another.

    --    > x = 1
    --    (...)
    
    --    > print (x)
    --    1

