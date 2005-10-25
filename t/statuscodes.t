use Test::More tests => 1;
use Data::Dumper;
use Bio::DasLite;
$Bio::DasLite::DEBUG = 0;

#########
# test single http fetch (on a non-DAS page!)
#
my $str  = "";
my $urls = {
	    'http://www.google.com/' => sub { $str .= $_[0]; return; }
	   };
my $das  = Bio::DasLite->new();
$das->features($urls);
ok(1);
