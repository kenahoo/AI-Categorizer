
use ExtUtils::MakeMaker;

my $module = 'AI::Classify';
my ($name, $dir);
($name = $module) =~ s/.*::(\w+)/$1.pm/;
($dir  = $module) =~ s/::/-/g;

WriteMakefile
  (
   'NAME'       => $module,
   'VERSION_FROM' => $name, # finds $VERSION
   'dist' => { COMPRESS=>"gzip",
               SUFFIX=>"gz",
               PREOP=>('rm -f README; '.
                       "pod2text -80 < $name > README; ".
                       "cp -f README $dir-\$(VERSION); "
                      ),
             },
   # 'clean' => {FILES => "t/httpd.conf t/error_log t/httpd"},
   'PREREQ_PM' => {
		   # Foo::Ey => '1.00',
		  },
   ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
    (ABSTRACT_FROM => $name, # retrieve abstract from module
     AUTHOR     => 'Ken Williams <ken@mathforum.org>') : 
    ()
   ),
  );

