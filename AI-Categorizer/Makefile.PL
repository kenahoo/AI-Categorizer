
use ExtUtils::MakeMaker;

my $module = 'AI::Categorizer';
my ($file, $dir);
($dir  = $module) =~ s/::/-/g;
($file = $module) =~ s{::}{/}g;
$file = "lib/$file.pm";

WriteMakefile
  (
   'NAME'       => $module,
   'VERSION_FROM' => $file, # finds $VERSION
   'dist' => { COMPRESS=>"gzip",
               SUFFIX=>"gz",
               PREOP=>('rm -f README; '.
                       "pod2text -80 < $file > README; ".
                       "cp -f README $dir-\$(VERSION); "
                      ),
             },
   # 'clean' => {FILES => "t/httpd.conf t/error_log t/httpd"},
   'PREREQ_PM' => {
		   Class::Container => 0.05,
		   Storable => 0,
		   Params::Validate => 0.18,
		  },

   # Recommended: Lingua::Stem

   ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
    (ABSTRACT_FROM => $file, # retrieve abstract from module
     AUTHOR     => 'Ken Williams <ken@mathforum.org>') : 
    ()
   ),
  );

