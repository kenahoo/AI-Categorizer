
use ExtUtils::MakeMaker;

my $module = 'AI::Categorizer';
my ($file, $dir);
($dir  = $module) =~ s/::/-/g;
($file = $module) =~ s{::}{/}g;
$file = "lib/$file.pm";

{
  my $path = prompt
    (
     "\nIf you have the Weka system installed, please specify the path\n".
     "to the 'weka.jar' file, or '-' to search CLASSPATH, or '!' to skip:",
     '!'
    );
  
  if ($path eq '!') {
    unlink "t/classpath" if -e "t/classpath";
  } else {
    local *FH;
    open FH, "> t/classpath" or die "Can't create t/classpath: $!";
    print FH $path;
    close FH;
  }
}

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
		   Class::Container => 0.07,
		   Storable => 0,
		   Params::Validate => 0.18,
		   Statistics::Contingency => 0.01,
		   Lingua::Stem => 0.50,
		  },

   # Recommended: Scalar::Util

   ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
    (ABSTRACT_FROM => $file, # retrieve abstract from module
     AUTHOR     => 'Ken Williams <ken@mathforum.org>') : 
    ()
   ),
  );

