use strict;
use Test::More tests => 5;
use Data::Dumper;

my $das      = Bio::DasLite::Test->new({'dsn' => 'http://foo/das/bar'});
my $features = $das->features();
my $results  = (values %$features)[0];

is(ref($results),                 "HASH", "Empty segment gives a hash with seginfo rather than an empty array of features");
is($results->{'segment_id'},      10,     "segment_id");
is($results->{'segment_version'}, 18,     "segment_version");
is($results->{'segment_start'},   1,      "segment_start");
is($results->{'segment_stop'},    1000,   "segment_stop");

package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  my $xml = qq(<?xml version='1.0' standalone='no' ?>
<!DOCTYPE DASGFF SYSTEM 'dasgff.dtd' >
<DASGFF>
  <GFF version="1.0" href="http://servlet.sanger.ac.uk:8080/das/ensembl1834/features?segment=10:1,1000">
    <SEGMENT id="10" version="18" start="1" stop="1000">
    </SEGMENT>
  </GFF>
</DASGFF>);

  for my $code_ref (values %$url_ref) {
    &$code_ref($xml);
  }
}

1;
