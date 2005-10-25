package Bio::DasLite::UserAgent;
use strict;
use LWP::Parallel::UserAgent;
use vars qw(@ISA);
@ISA = qw(LWP::Parallel::UserAgent);

our $VERSION = '0.02';

sub new {
  my ($class, %args) = @_;
  my $self = LWP::Parallel::UserAgent->new(%args);
  bless $self, $class;
  $self->{'http_proxy'} = $args{'http_proxy'} || $ENV{'http_proxy'};
  return $self;
}

sub _need_proxy {
  my $self = shift;
  $self->{'http_proxy'} or return;
  my ($scheme, $host, $port) = $self->{'http_proxy'} =~ m|(https?)://([^:\#\?/]+):?(\d+)?|;
  $host or return;
  my $proxy = {
	       'host'   => $host,
	       'port'   => $port   || "3128",
	       'scheme' => $scheme || "http",
	      };
  bless $proxy, "Bio::DasLite::UserAgent::proxy";
  return $proxy;
}

sub on_failure {
  my ($self, $request, $response, $entry)   = @_;
  $self->{'statuscodes'}                  ||= {};
  $self->{'statuscodes'}->{$request->url()} = $response->status_line();
  return;
}

sub on_return {
  return &on_failure(@_);
}

sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};
  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

1;

package Bio::DasLite::UserAgent::proxy;
sub host     { $_[0]->{'host'}; }
sub port     { $_[0]->{'port'}; }
sub scheme   { $_[0]->{'scheme'}; }

#########
# userinfo, presumably for authenticating to the proxy server.
# Not sure what format this is supposed to be (username:password@ ?)
# Things fail silently if this isn't present.
#
sub userinfo { ""; }
1;
