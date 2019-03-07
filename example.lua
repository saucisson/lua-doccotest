-- # Example:

-- The code to test is prefixed by at least four spaces and ">",
-- and the expected answer is put below.
-- Here, `return 1` is tested, and the result `1` is expected:
--    > return 1
--    1
-- Of course, other data types can be used, for instance:
--    > return "a"
--    "a"
--    > return true
--    true
--    > return { b = 1, a = 2 }
--    { a = 2, b = 1 }

-- Local variables can be defined within a code block:
--    > local a = 1
--    > local b = 2*a
--    > return b
--    2

-- But local variables disappear at the beginning of each code block:
--    > return a
--    nil

-- Global variables, on the contrary, live outside code blocks:
--    > c = 4
--    > return c
--    4
--    > return c
--    4

-- The `reset` command resets the environment,
-- and thus unset global variables:
--    /reset
--    > return c
--    nil

-- It is possible to store a result in a (global) variable:
--    > return 1
--    _.a
-- And even to extract a value from a table into a global variable:
--    > return { b = 2 }
--    { b = _.b }
-- These global variables can be used as any other variable:
--    > return a, b
--    1, 2
-- Variables that have been matched can be used also in expectations:
--    > return a + 1
--    b
