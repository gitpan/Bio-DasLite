use strict;
use Test::More tests => 1;
use Data::Dumper;

my $das      = Bio::DasLite::Test->new({'dsn' => 'http://foo/das/bar'});
my $features = $das->features();
my $results  = (values %$features)[0];

#diag(map { "$_->{'feature_id'}\n" } @$results);
#open(my $fh, ">t/chunk.out");
#print $fh Dumper($results);
#close($fh);
is(scalar @{$results}, 102, "Chunked-response-mode gave number of features returned");


package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  open(my $fh, "t/uniprot_features");
  while(my $xml = <$fh>) {
    for my $code_ref (values %$url_ref) {
#      &Test::More::diag("Calling $code_ref with @{[length($xml)]} bytes\n");
      &$code_ref($xml);
    }
  }
  close($fh);
}

1;
