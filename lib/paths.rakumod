# This is a naughty module, inspired by Rakudo::Internals.DIR-RECURSE
use nqp;

my class Files does Iterator {
    has str $!prefix;         # currently active prefix for entries
    has str $!dir-sep;        # directory separator to use
    has $!dir-matcher;        # matcher for accepting dir names
    has $!file-matcher;       # matcher for accepting file names
    has $!recurse;            # recurse on non-matching dirs?
    has $!follow-symlinks;    # whether to follow symlinks
    has $!handle;             # currently active nqp::opendir() handle
    has $!todo;               # list of abspaths of dirs to do still
    has $!seen;               # has of abspaths of dirs seen already
    has $!dir-accepts-files;  # produce files in current dir if accepted

    method !SET-SELF(
      str $abspath, $dir-matcher, $file-matcher, $recurse, $follow-symlinks
    ) {
        $!dir-matcher     := $dir-matcher;
        $!file-matcher    := $file-matcher;
        $!recurse         := $recurse;
        $!follow-symlinks := $follow-symlinks;
        $!dir-sep          = $*SPEC.dir-sep;

        $!seen := nqp::hash;
        $!todo := nqp::list_s;
        $!handle := nqp::opendir($abspath);
        $!prefix  = nqp::concat($abspath,$!dir-sep);
        $!dir-accepts-files := True;

        self
    }
    method new(
      str $abspath, $dir-matcher, $file-matcher, $recurse, $follow-symlinks
    ) {
        nqp::stat($abspath,nqp::const::STAT_EXISTS)
          ?? nqp::stat($abspath,nqp::const::STAT_ISDIR)
            ?? nqp::create(self)!SET-SELF(
                 $abspath, $dir-matcher, $file-matcher,
                 $recurse, $follow-symlinks
               )
            !! $file-matcher.ACCEPTS($abspath)
              ?? Rakudo::Iterator.OneValue($abspath)
              !! Rakudo::Iterator.Empty
          !! Rakudo::Iterator.Empty
    }

    method !entry(--> str) {
        nqp::until(
          nqp::isnull($!handle)
            || nqp::isnull_s(my str $entry = nqp::nextfiledir($!handle))
            || (nqp::isne_s($entry,'.') && nqp::isne_s($entry,'..')),
          nqp::null
        );
        nqp::if(nqp::isnull_s($entry),'',$entry)
    }

    method !next() {
        nqp::until(
          nqp::chars(my str $entry = self!entry),
          nqp::stmts(
            nqp::unless(
              nqp::isnull($!handle),
              nqp::stmts(
                nqp::closedir($!handle),
                ($!handle := nqp::null),
              )
            ),
            nqp::if(
              nqp::elems($!todo),
              nqp::stmts(
                (my str $abspath = nqp::pop_s($!todo)),
                nqp::handle(
                  ($!handle := nqp::opendir($abspath)),
                  'CATCH', 0
                ),
                nqp::unless(
                  nqp::isnull($!handle),
                  nqp::stmts(  # opendir failed
                    ($!dir-accepts-files := $!dir-matcher.ACCEPTS(
                      nqp::substr(
                        $abspath,
                        nqp::add_i(nqp::rindex($abspath,$!dir-sep),1)
                      )
                    )),
                    ($!prefix = nqp::concat($abspath,$!dir-sep))
                  )
                )
              ),
              return ''  # we're done, totally
            )
          )
        );
        $entry
    }

    method pull-one() {
        nqp::while(
          nqp::chars(my str $entry = self!next),
          nqp::if(
            nqp::stat(
              (my str $path = nqp::concat($!prefix,$entry)),
              nqp::const::STAT_EXISTS
            ),
            nqp::if(
              nqp::stat($path,nqp::const::STAT_ISREG)
                && $!dir-accepts-files
                && $!file-matcher.ACCEPTS($entry),
              (return $path),
              nqp::if(
                $!follow-symlinks || nqp::not_i(nqp::fileislink($path)),
                nqp::if(
                  nqp::stat($path,nqp::const::STAT_ISDIR),
                  nqp::stmts(
                    nqp::if(
                      nqp::fileislink($path),
                      $path = IO::Path.new(
                        $path,:CWD($!prefix)).resolve.absolute
                    ),
                    nqp::if(
                      nqp::not_i(nqp::existskey($!seen,$path))
                        && ($!recurse || $!dir-accepts-files),
                      nqp::stmts(
                        nqp::bindkey($!seen,$path,1),
                        nqp::push_s($!todo,$path)
                      )
                    )
                  )
                )
              )
            )
          )
        );
        IterationEnd
    }

    method is-deterministic(--> False) { }
}

my class Directories does Iterator {
    has str $!prefix;         # currently active prefix for entries
    has str $!dir-sep;        # directory separator to use
    has $!dir-matcher;        # matcher for accepting dir names
    has $!recurse;            # recurse on non-matching dirs?
    has $!follow-symlinks;    # whether to follow symlinks
    has $!handle;             # currently active nqp::opendir() handle
    has $!todo;               # list of abspaths of dirs to do still
    has $!seen;               # has of abspaths of dirs seen already

    method !SET-SELF(
      str $abspath, $dir-matcher, $recurse, $follow-symlinks
    ) {
        $!dir-matcher     := $dir-matcher;
        $!recurse         := $recurse.Bool;
        $!follow-symlinks := $follow-symlinks;
        $!dir-sep          = $*SPEC.dir-sep;

        $!seen := nqp::hash;
        $!todo := nqp::list_s;
        $!handle := nqp::opendir($abspath);
        $!prefix  = nqp::concat($abspath,$!dir-sep);

        self
    }
    method new(
      str $abspath, $dir-matcher, $recurse, $follow-symlinks
    ) {
        nqp::stat($abspath,nqp::const::STAT_EXISTS)
          && nqp::stat($abspath,nqp::const::STAT_ISDIR)
          ?? nqp::create(self)!SET-SELF(
               $abspath, $dir-matcher, $recurse, $follow-symlinks
             )
          !! Rakudo::Iterator.Empty
    }

    method !entry(--> str) {
        nqp::until(
          nqp::isnull($!handle)
            || nqp::isnull_s(my str $entry = nqp::nextfiledir($!handle))
            || (nqp::isne_s($entry,'.') && nqp::isne_s($entry,'..')),
          nqp::null
        );
        nqp::if(nqp::isnull_s($entry),'',$entry)
    }

    method !next() {
        nqp::until(
          nqp::chars(my str $entry = self!entry),
          nqp::stmts(
            nqp::unless(
              nqp::isnull($!handle),
              nqp::stmts(
                nqp::closedir($!handle),
                ($!handle := nqp::null),
              )
            ),
            nqp::if(
              nqp::elems($!todo),
              nqp::stmts(
                (my str $abspath = nqp::pop_s($!todo)),
                nqp::handle(
                  ($!handle := nqp::opendir($abspath)),
                  'CATCH', 0
                ),
                nqp::unless(
                  nqp::isnull($!handle),
                  ($!prefix = nqp::concat($abspath,$!dir-sep))
                )
              ),
              return ''  # we're done, totally
            )
          )
        );
        $entry
    }

    method pull-one() {
        nqp::while(
          nqp::chars(my str $entry = self!next),
          nqp::if(
            nqp::stat(
              (my str $path = nqp::concat($!prefix,$entry)),
              nqp::const::STAT_EXISTS
            ),
            nqp::if(
              $!follow-symlinks || nqp::not_i(nqp::fileislink($path)),
              nqp::if(
                nqp::stat($path,nqp::const::STAT_ISDIR),
                nqp::stmts(
                  nqp::if(
                    nqp::fileislink($path),
                    $path = IO::Path.new(
                      $path,:CWD($!prefix)).resolve.absolute
                  ),
                  (my $accepted := $!dir-matcher.ACCEPTS($entry)),
                  nqp::if(
                    nqp::not_i(nqp::existskey($!seen,$path))
                      && ($!recurse || $accepted),
                    nqp::stmts(
                      nqp::bindkey($!seen,$path,1),
                      nqp::push_s($!todo,$path)
                    )
                  ),
                  nqp::if(
                    $accepted,
                    (return $path)
                  )
                )
              )
            )
          )
        );
        IterationEnd
    }

    method is-deterministic(--> False) { }
}

my sub is-regular-file(str $path) is export {
    nqp::hllbool(
      nqp::stat($path,nqp::const::STAT_EXISTS)
        && nqp::stat($path,nqp::const::STAT_ISREG)
    )
}

my sub paths(
      $abspath? is copy,
  Mu :$dir      is copy,
  Mu :$file,
     :$recurse,
     :$follow-symlinks,
--> Seq:D) is export {

    $abspath = ($abspath // "./").IO.absolute;
    $dir   //= -> str $elem { nqp::not_i(nqp::eqat($elem,'.',0)) }

    Seq.new: $file<> =:= False
      ?? Directories.new: $abspath, $dir, $recurse, $follow-symlinks
      !! Files.new: $abspath, $dir, $file // True, $recurse, $follow-symlinks
}

my sub EXPORT(*@names) {
    Map.new: @names
      ?? @names.map: {
             if UNIT::{"&$_"}:exists {
                 UNIT::{"&$_"}:p
             }
             else {
                 my ($in,$out) = .split(':', 2);
                 if $out && UNIT::{"&$in"} -> &code {
                     Pair.new: "&$out", &code
                 }
             }
         }
      !! UNIT::.grep: {
             .key.starts-with('&') && .key ne '&EXPORT'
         }
}

=begin pod

=head1 NAME

paths - A fast recursive file / directory finder

=head1 SYNOPSIS

=begin code :lang<raku>

use paths;

.say for paths;                             # all files from current directory

.say for paths($dir);                       # all files from $dir

.say for paths(:dir(* eq '.git'));          # files in ".git" directories

.say for paths(:file(*.ends-with(".json");  # all .json files

.say for paths(:recurse);                   # also recurse in non-accepted dirs

.say for paths(:follow-symlinks);           # also recurse into symlinked dirs

.say for paths(:!file);                     # only produce directory paths

say is-regular-file('/etc/passwed');        # True (on Unixes)

=end code

=head1 DESCRIPTION

By default exports two subroutines: C<paths> (returning a C<Seq> of absolute
path strings of files (or directories) for the given directory and all its
sub-directories (with the notable exception of C<.> and C<..>).

And C<is-regular-file>, which returns a C<Bool> indicating whether the given
absolute path is a regular file.

=head1 SELECTIVE IMPORTING

=begin code :lang<raku>

use paths <paths>;  # only export sub paths

=end code

By default all utility functions are exported.  But you can limit this to
the functions you actually need by specifying the names in the C<use>
statement.

To prevent name collisions and/or import any subroutine with a more
memorable name, one can use the "original-name:known-as" syntax.  A
semi-colon in a specified string indicates the name by which the subroutine
is known in this distribution, followed by the name with which it will be
known in the lexical context in which the C<use> command is executed.

=begin code :lang<raku>

use path <paths:find-all-paths>;  # export "path-exists" as "alive"

.say for find-all-paths;

=end code

=head1 EXPORTED SUBROUTINES

=head2 paths

The C<paths> subroutine returns a C<Seq> of absolute path strings of files
for the given directory and all its sub-directories (with the notable
exception of C<.> and C<..>).

=head3 ARGUMENTS

=item directory

The only positional argument is optional: it can either be a path as a string
or as an C<IO> object.  It defaults to the current directory (also when an
undefined value is specified.  The (implicitely) specified directory will
B<always> be investigated, even if the directory name does not match the
C<:dir> argument.

If the specified path exists, but is not a directory, then only that path
will be produced if the file-matcher accepts the path.  In all other cases,
an empty C<Seq> will be returned.

=item :dir

The named argument C<:dir> accepts a matcher to be used in smart-matching
with the basename of the directories being found.  If accepted, will
produce both files as well as other directories to recurse into.

It defaults to skipping all of the directories that start with a period
(also if an undefined value is specified).

=item :file

The named argument C<:file> accepts a matcher to be used in smart-matching
with the basename of the file being found.  It defaults to C<True>, meaning
that all possible files will be produced (also if an undefined values is
specified).

If the boolean value C<False> is specified, then B<only> the paths of
directories will be produced.

=item :recurse

Flag.  The named argument C<:recurse> accepts a boolean value to indicate
whether subdirectories that did B<not> match the C<:dir> specification,
should be investigated as well for other B<directories> to recurse into.
No files will be produced from a directory that didn't match the C<:dir>
argument.

By default, it will not recurse into directories.

=item :follow-symlinks

The named argument C<:follow-symlinks> accepts a boolean value to indicate
whether subdirectories, that are actually symbolic links to a directory,
should be investigated as well.  By default, it will not.

=head2 is-regular-file

=begin code :lang<raku>

say is-regular-file('/etc/passwed');  # True (on Unixes)

=end code

Returns a C<Bool> indicating whether the given absolute path is a regular
file.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/paths . Comments and
Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2021, 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
