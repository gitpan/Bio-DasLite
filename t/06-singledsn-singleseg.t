use Test::More tests => 17;
use strict;

my $src  = [qw(http://servlet.sanger.ac.uk/das/ensembl1834)];
my $das  = Bio::DasLite::Test->new({
				    'dsn'     => $src,
				    'timeout' => 30,
				   });
#my $dsns = $das->dsns();
#ok(ref($dsns) eq "HASH", "dsns gives a hash (keyed on URL) of arrays");

my $req = "10:1,1000";
for my $call (qw(entry_points types features sequence)) {
  my $res       = $das->$call($req);
  ok(ref($res) eq "HASH",                 "$call returns a hash");
  ok(scalar keys %$res == scalar @{$src}, "$call returns the same number of sources");
  ok(ref((values %{$res})[0]) eq "ARRAY", "$call hash contains an array");

  #########
  # check return codes
  #
  my $codes = $das->statuscodes();
  my $code  = 0;
  for my $u (keys %$codes) {
    if($u =~ /$call.*10:1,1000/) {
      $code = substr($codes->{$u}, 0, 3);
      last;
    }
  }
  if($code == 200) {
    ok(scalar @{(values %{$res})[0]} > 0,   "$call returns some data");

  } elsif($code == 500) {
    diag("$call call failed due to server error");
    pass();
  }
}

my $sequence = $das->sequence("1:1,1000");
my $key      = (keys %{$sequence})[0];
my $seq      = $sequence->{$key}->[0]->{'sequence'} || "";
$seq         =~ s/\s+//smg;

is(length($seq), 1000, "requesting 1Kb of sequence returns 1Kb");




package Bio::DasLite::Test;
use base "Bio::DasLite";

sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  my $datafile = {
		  'entry_points' => 't/ensembl1834_entry_points',
		  'types'        => 't/ensembl1834_types',
		  'features'     => 't/ensembl1834_features',
		  'sequence'     => 't/ensembl1834_sequence',
		 };


  for my $url (keys %$url_ref) {
    my ($cmd) = $url =~ m|.*/([^/\?\#]+)|;
    my $fn    = $datafile->{$cmd};
    open(my $fh, $fn) or die "No file available for $cmd test";
    local $/ = undef;
    my $xml  = <$fh>;
    close($fh);

    my $code_ref = $url_ref->{$url};
    &$code_ref($xml);
    $self->{'statuscodes'}->{$url} = 200;
  }
}
1;

