use strict;
use Test::More tests => 1;
use Data::Dumper;

my $das      = Bio::DasLite::Test->new({'dsn' => 'foo'});
my $features = $das->features();
my $results  = (values %$features)[0];

#diag(map { "$_->{'feature_id'}\n" } @$results);
#open(my $fh, ">t/block.out");
#print $fh Dumper($results);
#close($fh);
is(scalar @{$results}, 102, "Whole-response-mode gave correct number of features returned");

package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  open(my $fh, "t/uniprot_features");
  local $/ = undef;
  my $xml  = <$fh>;
  close($fh);

  for my $code_ref (values %$url_ref) {
    &$code_ref($xml);
  }
}

1;
