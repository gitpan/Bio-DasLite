use Test::More tests => 3;
use Bio::DasLite;
use Data::Dumper;

my $das = Bio::DasLite->new({
   'http_proxy' => 'https://foo:bar@webcache.example.com:3128/',
});

is($das->http_proxy(), "https://webcache.example.com:3128/", "http_proxy processed ok");
is($das->proxy_user(), "foo", "proxy_user processed ok");
is($das->proxy_pass(), "bar", "proxy_pass processed ok");

