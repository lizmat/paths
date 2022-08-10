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

.say for paths(:follow-symlinks);           # also recurse into symlinked dirs

say is-regular-file('/etc/passwed');        # True (on Unixes)
```

DESCRIPTION
===========

Exports two subroutines: `paths` (returning a `Seq` of absolute path strings of files for the given directory and all its sub-directories (with the notable exception of `.` and `..`). And `is-regular-file`, which returns a `Bool` indicating whether the given absolute path is a regular file.

EXPORTED SUBROUTINES
====================

paths
-----

The `paths` subroutine returns a `Seq` of absolute path strings of files for the given directory and all its sub-directories (with the notable exception of `.` and `..`).

### ARGUMENTS

  * directory

The only positional argument is optional: it can either be a path as a string or as an `IO` object. It defaults to the current directory (also when an undefined value is specified. The (implicitely) specified directory will **always** be investigated, even if the directory name does not match the `:dir` argument.

If the specified path exists, but is not a directory, then only that path will be produced if the file-matcher accepts the path. In all other cases, an empty `Seq` will be returned.

  * :dir

The named argument `:dir` accepts a matcher to be used in smart-matching with the basename of the directories being found. It defaults to skipping all of the directories that start with a period (also if an undefined value is specified).

  * :file

The named argument `:file` accepts a matcher to be used in smart-matching with the basename of the file being found. It defaults to `True`, meaning that all possible files will be produced (also if an undefined values is specified).

  * :recurse

The named argument `:recurse` accepts a boolean value to indicate whether subdirectories that did **not** match the `:dir` specification, should be investigated as well. By default, it will not.

  * :follow-symlinks

The named argument `:follow-symlinks` accepts a boolean value to indicate whether subdirectories, that are actually symbolic links to a directory, should be investigated as well. By default, it will not.

is-regular-file
---------------

```raku
say is-regular-file('/etc/passwed');  # True (on Unixes)
```

Returns a `Bool` indicating whether the given absolute path is a regular file.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/paths . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2021, 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

