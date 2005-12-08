use Test::More tests => 9;
use Bio::DasLite;
$Bio::DasLite::DEBUG = 0;

{
  my $das = Bio::DasLite->new();
  ok(defined $das,                       "new returned something");
  ok($das->isa("Bio::DasLite"),          "and it's the right class");
}

{
  my $rnd = int(rand(60))+1;
  ok(Bio::DasLite->new({'timeout'    => $rnd})->timeout() == $rnd, "get/set timeout");
  my $proxy = "http://webcache.localnet:3128/";
  ok(Bio::DasLite->new({'http_proxy' => $proxy})->http_proxy() eq $proxy, "get/set http_proxy");
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

{
  my $das      = Bio::DasLite->new({
				    'dsn'     => 'http://das.sanger.ac.uk/das/decipher',
				    'timeout' => 30,
				   });
  ok($das->stylesheet());
}
