
use ExtUtils::MakeMaker;
use Config;

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
    unlink "classpath" if -e "classpath";
  } else {
    local *FH;
    open FH, "> classpath" or die "Can't create classpath: $!";
    print FH $path;
    close FH;
  }
}

my %options;
{
  if (prompt("Do you want to install the command-line script 'categorizer' to $Config::Config{installscript}?", 'n') =~ /^y/i) {
    $options{EXE_FILES} = [qw(eg/categorizer)];
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
   'clean' => {FILES => "t/state"},
   'PREREQ_PM' => {
		   Class::Container => 0.08,
		   Storable => 0,
		   Params::Validate => 0.18,
		   Statistics::Contingency => 0.06,
		   Lingua::Stem => 0.50,
		  },
   'PL_FILES' => {},
   %options,

   # Recommended: Scalar::Util

   ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
    (ABSTRACT_FROM => $file, # retrieve abstract from module
     AUTHOR     => 'Ken Williams <ken@mathforum.org>') : 
    ()
   ),
  );

