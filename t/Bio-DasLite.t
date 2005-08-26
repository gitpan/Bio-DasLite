use Test::More tests => 39;
use Bio::DasLite;

{
  my $das = Bio::DasLite->new();
  ok(defined $das,                       "new returned something");
  ok($das->isa("Bio::DasLite"),          "and it's the right class");
}

{
  my $rnd = int(rand(60));
  ok(Bio::DasLite->new({'timeout'    => $rnd})->timeout() == $rnd, "get/set timeout");
  my $proxy = "http://webcache.localnet:3128/";
  ok(Bio::DasLite->new({'http_proxy' => $proxy})->http_proxy() eq $proxy, "get/set http_proxy");
}

{
  #########
  # test dsn
  #
  my $services = [qw(http://das.sanger.ac.uk/das/dsn http://das.ensembl.org/das/dsn)];
  my $das = Bio::DasLite->new();
  ok($das->dsn($services),               "service set many");
  ok($das->dsn() eq $services,           "service get many");

  my $service = "http://das.sanger.ac.uk/das/dsn";
  ok($das->dsn($service),                "service set one");
  ok(scalar @{$das->dsn()} == 1,         "service get one");

  #########
  # test service basename
  #
  ok($das->basename()->[0] eq "http://das.sanger.ac.uk/das", "service basename");
}

{
  #########
  # test single http fetch (on a non-DAS page!)
  #
  my $str  = "";
  my $urls = {
	      'http://www.google.com/' => sub { $str .= $_[0]; return; }
	     };
  my $das  = Bio::DasLite->new();
  $das->_fetch($urls);
  ok($str =~ m|<html.*/html>|smi, "plain http fetch");
}

{
  #########
  # test real DAS calls
  #
  my $src  = [qw(http://servlet.sanger.ac.uk/das/ensembl1834)];
  my $das  = Bio::DasLite->new({
				'dsn'     => $src,
				'timeout' => 30,
			       });
  my $dsns = $das->dsns();
  ok(ref($dsns) eq "HASH", "dsns gives a hash (keyed on URL) of arrays");

  my $req = "10:1,1000";
  for my $call (qw(entry_points types features sequence)) {
    my $res       = $das->$call($req);
    ok(ref($res) eq "HASH",                 "$call returns a hash");
    ok(scalar keys %$res == scalar @{$src}, "$call returns the same number of sources");
    ok(ref((values %{$res})[0]) eq "ARRAY", "$call hash contains an array");
    ok(scalar @{(values %{$res})[0]} > 0,   "$call returns some data");
  }

  $req = ["1:1,1000", "15:1,1000"];
  for my $call (qw(features sequence)) {
    my $res       = $das->$call($req);
    ok(ref($res) eq "HASH",                    "$call returns a hash");
    ok(scalar keys %$res == (@{$src}*@{$req}), "$call returns data to the tune of (number of sources * number of segments)");
    ok(ref((values %{$res})[0]) eq "ARRAY",    "$call hash contains an array");
    ok(scalar @{(values %{$res})[0]} > 0,      "$call returns some data");
  }

  my $sequence = $das->sequence("1:1,1000");
  my $key      = (keys %{$sequence})[0];
  my $seq      = $sequence->{$key}->[0]->{'sequence'};
  $seq         =~ s/\s+//smg;
  ok(length($seq) == 1000, "requesting 1Kb of sequence returns 1Kb");
}

{
  my $das      = Bio::DasLite->new({
				    'dsn'     => 'http://das.sanger.ac.uk/das/spectral35',
				    'timeout' => 30,
				   });
  my $f_by_id  = $das->features({'feature_id' => "RP5-1119A7"});
  ok(ref($f_by_id) eq "HASH",      "feature-by-id returned a list");

  my $key      = (keys %{$f_by_id})[0];
  ok(scalar @{$f_by_id->{$key}} <= 1,      "feature-by=id returned one or no elements");
  ok(ref($f_by_id->{$key}->[0]) eq "HASH", "feature-by-id element was a hash");
}
