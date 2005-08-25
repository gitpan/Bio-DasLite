use Test::More tests => 18;
use Bio::DasLite;

my $das = Bio::DasLite->new();
ok(defined $das,                       "new returned something");
ok($das->isa("Bio::DasLite"),          "and it's the right class");

my $rnd = int(rand(60));
ok(Bio::DasLite->new({'timeout'    => $rnd})->timeout() == $rnd, "get/set timeout");
my $proxy = "http://webcache.localnet:3128/";
ok(Bio::DasLite->new({'http_proxy' => $proxy})->http_proxy() eq $proxy, "get/set http_proxy");

#########
# test dsn
#
my $services = [qw(http://das.sanger.ac.uk/das/dsn http://das.ensembl.org/das/dsn)];
ok($das->dsn($services),               "service set many");
ok($das->dsn() eq $services,           "service get many");

my $service = "http://das.sanger.ac.uk/das/dsn";
ok($das->dsn($service),                "service set one");
ok($service eq $das->dsn(),            "service get one");

#########
# test service basename
#
ok($das->basename() eq "http://das.sanger.ac.uk/das", "service basename");

#########
# test single http fetch (on a non-DAS page!)
#
my $str  = "";
my $urls = {
	    'http://www.google.com/' => sub { $str .= $_[0]; return; }
	   };

$das->_fetch($urls);
ok($str =~ m|<html.*/html>|smi, "plain http fetch");

my $dsns = $das->dsns();
ok(ref($dsns) eq "ARRAY" ||
   ref($dsns) eq "HASH", "dsns gives an array of dsns for a single dsn or hashed list for multiple dsns");

$das         = Bio::DasLite->new({
				  'dsn' => 'http://servlet.sanger.ac.uk/das/ensembl1834',
				  'timeout' => 30,
				 });
my $ep       = $das->entry_points();
ok(ref($ep) eq "ARRAY", "entry_points returns an array");
ok(scalar @{$ep} > 0, "entry_points returns some data");

my $types    = $das->types();
ok(ref($types) eq "ARRAY", "types returns an array");
ok(scalar @{$types} > 0, "types returns some data");

my $features = $das->features("10:1,1000");
ok(ref($features) eq "ARRAY", "features returns an array");
ok(scalar @{$features} > 0, "features returns some data");

my $sequence = $das->sequence("1:1,1000");
my $seq      = $sequence->[0]->{'sequence'};
$seq         =~ s/\s+//smg;
ok(length($seq) == 1000, "requesting 1Kb of sequence returns 1Kb");
