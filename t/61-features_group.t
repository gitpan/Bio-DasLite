use strict;
use Test::More tests => 5;
use Data::Dumper;

my $das      = Bio::DasLite::Test->new({'dsn' => 'foo'});
my $features = $das->features();
my $results  = (values %$features)[0];

my $first_feature_group_data = $results->[0]->{'group'}->[0];
is(scalar @{$first_feature_group_data->{'link'}}, 2, "Corrent number of links returned");
is(scalar @{$first_feature_group_data->{'note'}}, 2, "Corrent number of notes returned");
is($first_feature_group_data->{'link'}->[1]->{'href'}, "groupurl2", "Correct link href");
is($first_feature_group_data->{'link'}->[1]->{'txt'},  " group link text 2", "Correct link text");
is($first_feature_group_data->{'note'}->[1], " group note 2 text ", "Correct note text");

package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  my $xml = qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASGFF SYSTEM "http://www.biodas.org/dtd/dasgff.dtd">
<DASGFF>
  <GFF version="1.0" href="url">
  <SEGMENT id="id" start="start" stop="stop" type="type" version="X.XX" label="label">
      <FEATURE id="id" label="label">
         <TYPE id="id" category="category" reference="yes|no">type label</TYPE>
         <METHOD id="id"> method label </METHOD>
         <START> start </START>
         <END> end </END>
         <SCORE> [X.XX|-] </SCORE>
         <ORIENTATION> [0|-|+] </ORIENTATION>
         <PHASE> [0|1|2|-]</PHASE>
         <NOTE> note text </NOTE>
	 <LINK href="url"> link text </LINK>
	 <TARGET id="id" start="x" stop="y">target name</TARGET>
	 <GROUP id="id" label="label" type="type">
	       <NOTE> group note 1 text </NOTE>
	       <LINK href="groupurl1"> group link text 1</LINK>
	       <NOTE> group note 2 text </NOTE>
	       <LINK href="groupurl2"> group link text 2</LINK>
	       <TARGET id="id" start="x" stop="y">target name</TARGET>
         </GROUP>
      </FEATURE>
  </SEGMENT>
  </GFF>
</DASGFF>\n);

  for my $code_ref (values %$url_ref) {
    &$code_ref($xml);
  }
}

1;
