use Module::Build;
use Config;
use File::Spec;

my $build = new Module::Build
  (
   module_name => 'AI::Categorizer',
   license => 'perl',
   ##{ $plugin->get_prereqs(1) ##}
   create_makefile_pl => 'passthrough',
  );

my $categorizer = File::Spec->catfile('eg', 'categorizer');
if ($build->y_n("Do you want to install the $categorizer script to $Config{installscript}?", 'n')) {
  $build->scripts($categorizer);
}


$build->create_build_script;

{
  my $path = $build->prompt
    (
     "\nIf you have the Weka system installed, please specify the path\n".
     "to the 'weka.jar' file, or '-' to search CLASSPATH, or '!' to skip:",
     '!'
    );
  $build->notes(classpath => $path eq '!' ? undef : $path);
}
