# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN { 
  plan tests => 5;
};

use AI::Categorizer::Util qw(random_elements);
ok(1);

my @x = ('a'..'j');
my @y = random_elements(\@x, 3);
ok @y, 3;
ok $y[0] =~ /^[a-j]$/;

@y = random_elements(\@x, 7);
ok @y, 7;
ok $y[0] =~ /^[a-j]$/;
