# This is a naughty module, inspired by Rakudo::Internal.DIR-RECURSE
use nqp;

my
class paths:ver<0.0.2>:auth<zef:lizmat> does Iterator {
    has str $!prefix;         # currently active prefix for entries
    has str $!dir-sep;        # directory separator to use
    has $!dir-matcher;        # matcher for accepting dir names
    has $!file-matcher;       # matcher for accepting file names
    has $!recurse;            # recurse on non-matching dirs?
    has $!handle;             # currently active nqp::opendir() handle
    has $!todo;               # list of abspaths of dirs to do still
    has $!seen;               # has of abspaths of dirs seen already
    has $!dir-accepts-files;  # produce files in current dir if accepted

    method !SET-SELF(str $abspath, $dir-matcher, $file-matcher, $recurse) {
        $!dir-matcher  := $dir-matcher;
        $!file-matcher := $file-matcher;
        $!recurse      := $recurse;
        $!dir-sep       = $*SPEC.dir-sep;

        $!seen := nqp::hash;
        $!todo := nqp::list_s;
        $!handle := nqp::opendir($abspath);
        $!prefix  = nqp::concat($abspath,$!dir-sep);
        $!dir-accepts-files := True;

        self
    }
    method new(str $abspath, $dir-matcher, $file-matcher, $recurse) {
        nqp::stat($abspath,nqp::const::STAT_EXISTS)
          && nqp::stat($abspath,nqp::const::STAT_ISDIR)
          ?? nqp::create(self)!SET-SELF(
               $abspath, $dir-matcher, $file-matcher, $recurse
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
        );
        IterationEnd
    }
}

my sub paths(
  $abspath  = ".",
  Mu :$dir  = -> str $elem { nqp::not_i(nqp::eqat($elem,'.',0)) },
  Mu :$file = True,
     :$recurse,
) is export {
    Seq.new: paths.new($abspath.IO.absolute, $dir, $file, $recurse)
}

=begin pod

=head1 NAME

paths - a fast recursive file finder

=head1 SYNOPSIS

=begin code :lang<raku>

use paths;

.say for paths;                             # all files from current directory

.say for paths($dir);                       # all files from $dir

.say for paths(:dir(* eq '.git'));          # files in ".git" directories

.say for paths(:file(*.ends-with(".json");  # all .json files

.say for paths(:recurse);                   # also recurse in non-accepted dirs

=end code

=head1 DESCRIPTION

Exports a subroutine C<paths> that creates a C<Seq> of absolute path strings
of files for the given directory and all its sub-directories (with the notable
exception of C<.> and C<..>).

=head1 ARGUMENTS

=item directory

The only positional argument is optional: it can either be a path as a string
or as an C<IO> object.  It defaults to the current directory.  Thei
(implicitely) specified directory will B<always> be investigated, even if the
directory name does not match the C<:dir> argument.

=item :dir

The named argument C<:dir> accepts a matcher to be used in smart-matching
with the basename of the directories being found.  It defaults to skipping
all of the directories that start with a period.

=item :file

The named argument C<:file> accepts a matcher to be used in smart-matching
with the basename of the file being found.  It defaults to C<True>, meaning
that all possible files will be produced.

=item :recurse

The named argument C<:recurse> accepts a boolean value to indicate whether
subdirectories that did B<not> match the C<:dir> specification, should be
investigated as well.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/paths . Comments and
Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2021 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
