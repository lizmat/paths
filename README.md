[![Actions Status](https://github.com/lizmat/paths/workflows/test/badge.svg)](https://github.com/lizmat/paths/actions)

NAME
====

paths - a fast recursive file finder

SYNOPSIS
========

```raku
use paths;

.say for paths;                             # all files from current directory

.say for paths($dir);                       # all files from $dir

.say for paths(:dir(* eq '.git'));          # files in ".git" directories

.say for paths(:file(*.ends-with(".json");  # all .json files

.say for paths(:recurse);                   # also recurse in non-accepted dirs
```

DESCRIPTION
===========

Exports a subroutine `paths` that creates a `Seq` of absolute path strings of files for the given directory and all its sub-directories (with the notable exception of `.` and `..`).

ARGUMENTS
=========

  * directory

The only positional argument is optional: it can either be a path as a string or as an `IO` object. It defaults to the current directory.

  * :dir

The named argument `:dir` accepts a matcher to be used in smart-matching with the basename of the directories being found. It defaults to skipping all of the directories that start with a period.

  * :file

The named argument `:file` accepts a matcher to be used in smart-matching with the basename of the file being found. It defaults to `True`, meaning that all possible files will be produced.

  * :recurse

The named argument `:recurse` accepts a boolean value to indicate whether subdirectories that did **not** match the `:dir` specification, should be investigated as well.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/paths . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

