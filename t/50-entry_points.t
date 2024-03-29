use strict;
use Test::More tests => 1;
use Data::Dumper;
my $das     = Bio::DasLite::Test->new({'dsn' => 'foo'});
my $ep      = $das->entry_points();
my $results = (values %$ep)[0];

#print STDERR Dumper($results);

is(scalar @{$results->[0]->{'segment'}}, 22, "Correct number of segments returned");

package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  my $xml = qq(<?xml version='1.0' standalone='no' ?>
<!DOCTYPE DASEP SYSTEM 'dasep.dtd' >
<DASEP>
  <ENTRY_POINTS href="http://das1:8080/das/ensembl_Mus_musculus_core_28_33d/entry_points?" version="28_33d">
    <SEGMENT id="3" size="160575607" subparts="yes" />
    <SEGMENT id="7" size="133051633" subparts="yes" />
    <SEGMENT id="18" size="91083707" subparts="yes" />
    <SEGMENT id="2" size="181686250" subparts="yes" />
    <SEGMENT id="MT" size="16299" subparts="yes" />
    <SEGMENT id="14" size="117079080" subparts="yes" />

    <SEGMENT id="17" size="93559791" subparts="yes" />
    <SEGMENT id="6" size="149721531" subparts="yes" />
    <SEGMENT id="1" size="195203927" subparts="yes" />
    <SEGMENT id="10" size="130633972" subparts="yes" />
    <SEGMENT id="5" size="149219885" subparts="yes" />
    <SEGMENT id="16" size="98801893" subparts="yes" />
    <SEGMENT id="13" size="116458020" subparts="yes" />
    <SEGMENT id="Y" size="47900188" subparts="yes" />
    <SEGMENT id="9" size="124177049" subparts="yes" />

    <SEGMENT id="11" size="121648857" subparts="yes" />
    <SEGMENT id="15" size="104138553" subparts="yes" />
    <SEGMENT id="4" size="154141344" subparts="yes" />
    <SEGMENT id="19" size="60688862" subparts="yes" />
    <SEGMENT id="8" size="128688707" subparts="yes" />
    <SEGMENT id="12" size="115071072" subparts="yes" />
    <SEGMENT id="X" size="160634946" subparts="yes" />
  </ENTRY_POINTS>
</DASEP>\n);

  for my $code_ref (values %$url_ref) {
    &$code_ref($xml);
  }
}
1;
