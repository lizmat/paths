# This is a naughty module, inspired by Rakudo::Internals.DIR-RECURSE
use nqp;

my class Files does Iterator {
    has str $!prefix;         # currently active prefix for entries
    has str $!dir-sep;        # directory separator to use
    has $!dir-matcher;        # matcher for accepting dir names
    has $!file-matcher;       # matcher for accepting file names
    has $!recurse;            # recurse on non-matching dirs?
    has $!readable-files;     # only produce readable files
    has $!follow-symlinks;    # whether to follow symlinks
    has $!handle;             # currently active nqp::opendir() handle
    has $!todo;               # list of abspaths of dirs to do still
    has $!seen;               # has of abspaths of dirs seen already
    has $!dir-accepts-files;  # produce files in current dir if accepted

    method !SET-SELF(
      str $abspath, $dir-matcher, $file-matcher,
      $recurse, $follow-symlinks, $readable-files
    ) {

        # Set up first dir, return empty handed if failed
        nqp::handle(
          ($!handle := nqp::opendir($abspath)),
          'CATCH', (return Rakudo::Iterator.Empty)
        );

        $!dir-matcher     := $dir-matcher;  # UNCOVERABLE
        $!file-matcher    := $file-matcher;  # UNCOVERABLE
        $!recurse         := $recurse;  # UNCOVERABLE
        $!follow-symlinks := $follow-symlinks;  # UNCOVERABLE
        $!readable-files  := $readable-files;  # UNCOVERABLE
        $!dir-sep          = $*SPEC.dir-sep;

        $!seen  := nqp::hash;  # UNCOVERABLE
        $!todo  := nqp::list_s;  # UNCOVERABLE
        $!prefix = nqp::concat($abspath,$!dir-sep);  # UNCOVERABLE
        $!dir-accepts-files := True;  # UNCOVERABLE

        self
    }
    method new(
      str $abspath, $dir-matcher, $file-matcher,
      $recurse, $follow-symlinks, $readable-files
    ) {
        nqp::stat($abspath,nqp::const::STAT_EXISTS)
          ?? nqp::stat($abspath,nqp::const::STAT_ISDIR)
            ?? nqp::create(self)!SET-SELF(
                 $abspath, $dir-matcher, $file-matcher,
                 $recurse, $follow-symlinks, $readable-files
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
                && nqp::iseq_i($!readable-files,nqp::filereadable($path))
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

    method is-deterministic(--> False) { }  # UNCOVERABLE
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

        # Set up first dir, return empty handed if failed
        nqp::handle(
          ($!handle := nqp::opendir($abspath)),
          'CATCH', (return Rakudo::Iterator.Empty)
        ),

        $!dir-matcher     := $dir-matcher;
        $!recurse         := $recurse.Bool;
        $!follow-symlinks := $follow-symlinks;  # UNCOVERABLE
        $!dir-sep          = $*SPEC.dir-sep;

        $!seen  := nqp::hash;  # UNCOVERABLE
        $!todo  := nqp::list_s;  # UNCOVERABLE
        $!prefix = nqp::concat($abspath,$!dir-sep);  # UNCOVERABLE

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

    method is-deterministic(--> False) { }  # UNCOVERABLE
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
  Bool:D :$readable-files = True,
--> Seq:D) is export {

    $abspath = ($abspath // "./").IO.absolute;
    $dir   //= -> str $elem { nqp::not_i(nqp::eqat($elem,'.',0)) }

    Seq.new: $file<> =:= False
      ?? Directories.new: $abspath, $dir, $recurse, $follow-symlinks
      !! Files.new: $abspath, $dir, $file // True,
                    $recurse, $follow-symlinks, $readable-files.Int
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

# vim: expandtab shiftwidth=4
