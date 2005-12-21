package Bio::DasLite;
#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    rmp@sanger.ac.uk
# Created:       2005-08-23
# Last Modified: 2005-10-24
#
use strict;
use warnings;
use Bio::DasLite::UserAgent;
use HTTP::Request;
use HTTP::Headers;

our $DEBUG    = 0;
our $VERSION  = '0.13';
our $BLK_SIZE = 8192;
our $TIMEOUT  = 5;
our $MAX_REQ  = 5;

#########
# $ATTR contains information about document structure - tags, attributes and subparts
# This is split up by call to reduce the number of tag passes for each response
#
our %common_style_attrs = (
			   'yoffset'	    => [], # WTSI extension (available in Ensembl)
			   'scorecolormin'  => [], # WTSI extension
			   'scorecolormax'  => [], # WTSI extension
			   'scoreheightmin' => [], # WTSI extension
			   'scoreheightmax' => [], # WTSI extension
			   'zindex'         => [], # WTSI extension (available in Ensembl)
			   'height'         => [],
			   'fgcolor'        => [],
			   'bgcolor'        => [],
			   'label'          => [],
			   'bump'           => [],
			  );
our $ATTR     = {
		 '_segment'     => {
				    'segment'      => [qw(id start stop version label)],
				   },
		 'feature'      => {
				    'feature'      => [qw(id label)],
				    'method'       => [qw(id)],
				    'type'         => [qw(id category reference subparts superparts)],
				    'target'       => [qw(id start stop)],
				    'start'        => [],
				    'end'          => [],
				    'orientation'  => [],
				    'phase'        => [],
				    'score'        => [],
				    'group'        => {
						       'group'   => [qw(id label type)],
						       'target'  => [qw(id start stop)],
						      },
			           },
		 'sequence'     => {
				    'sequence'     => [qw(id start stop moltype version)],
				   },
		 'entry_points' => {
				    'entry_points' => [qw(href version)],
				    'segment'      => [qw(id start stop type orientation size subparts)],
				   },
		 'dsn'          => {
				    'dsn'          => [],
				    'source'       => [qw(id)],
				    'mapmaster'    => [],
				    'description'  => [],
				   },
		 'type'         => {
				    'type'         => [qw(id method category)],                           # types request
				    'segment'      => [qw(id start stop type orientation size subparts)],
				   },
		 'stylesheet'   => {
				    'stylesheet' => [qw(version)],
				    'category'   => {
						     'category' => [qw(id)],
						     'type'     => {
								    'type'  => [qw(id)],
								    'glyph' => {
										'arrow'          => {
												     %common_style_attrs,
												     'parallel'     => [],
												    },
										'anchored_arrow' => {
												     %common_style_attrs,
												     'parallel'     => [],
												     'orientation'  => [], # WTSI extension
												     'no_anchor'    => [], # WTSI extension
												    },
										'box'            => {
												     %common_style_attrs,
												     'linewidth'   => [],
												     'pattern'     => [],  # WTSI extension
												    },
										'farrow'         => {                      # WTSI extension
												     %common_style_attrs,
												     'orientation' => [],
												     'no_anchor'   => [],
												    },
										'rarrow'         => {                      # WTSI extension
												     %common_style_attrs,
												     'orientation' => [],
												     'no_anchor'   => [],
												    },
										'cross'          => {
												     %common_style_attrs,
												     'linewidth'   => [],  # WTSI extension
												    },
										'dot'            => \%common_style_attrs,
										'ex'             => {
												     %common_style_attrs,
												     'linewidth'   => [],  # WTSI extension
												    },
										'hidden'         => \%common_style_attrs,
										'line'           => {
												     %common_style_attrs,
												     'style'       => [],
												    },
										'span'           => \%common_style_attrs,
										'text'           => {
												     %common_style_attrs,
												     'font'        => [],
												     'fontsize'    => [],
												     'string'      => [],
												     'style'       => [],
												    },
										'primers'        => \%common_style_attrs,
										'toomany'        => {
												     %common_style_attrs,
												     'linewidth'    => [],
												    },
										'triangle'       => {
												     %common_style_attrs,
												     'linewidth'    => [],
												     'direction'    => [],
												     'orientation'  => [],
												    },
									       },
								   },
						    },
				   },
		};

#########
# $OPTS contains information about parameters to use for queries
#
our $OPTS = {
	     'feature'      => [qw(segment type category categorize feature_id group_id)],
	     'type'         => [qw(segment type)],
	     'sequence'     => [qw(segment)],
	     'entry_points' => [],
	     'dsn'          => [],
	     'stylesheet'   => [],
	    };
=head1 NAME

Bio::DasLite - Perl extension for the DAS (HTTP+XML) Protocol (http://biodas.org/)

=head1 SYNOPSIS

  use Bio::DasLite;

=cut


=head2 new : Constructor

  my $das = Bio::DasLite->new({
			       'timeout'    => 60,                                       # optional timeout in seconds
                               'dsn'        => "http://das.ensembl.org/das/ensembl1834", # optional DSN (scalar, or arrayref)
                               'http_proxy' => "http://webcache.local.com:3128",         # optional http proxy
			      });

 Options can be: dsn        (optional scalar or array ref, URLs of DAS services)
                 timeout    (optional int,      HTTP fetch timeout in seconds)
                 http_proxy (optional scalar,   web cache or proxy if not set in %ENV)
                 caching    (optional bool,     primitive caching on/off)
                 callback   (optional code ref, callback for processed xml blocks)

=cut
#########
# Public methods
#
sub new {
  my ($class, $ref) = @_;
  my $self = {
	      'dsn'     => [],
	      'timeout' => $TIMEOUT,
	      'data'    => {},
	      'caching' => 1,
	     };

  bless $self, $class;

  for my $arg (qw(dsn timeout http_proxy caching callback)) {
    $self->$arg($ref->{$arg}) if(defined $ref->{$arg} && $self->can($arg));
  }

  return $self;
}

=head2 http_proxy : Get/Set http_proxy

    $das->http_proxy("http://squid.myco.com:3128/");

=cut
sub http_proxy {
  my ($self, $proxy)    = @_;
  $self->{'http_proxy'} = $proxy if($proxy);
  return $self->{'http_proxy'};
}

=head2 timeout : Get/Set timeout

    $das->timeout(30);

=cut
sub timeout {
  my ($self, $timeout) = @_;
  $self->{'timeout'}   = $timeout if($timeout);
  return $self->{'timeout'};
}

=head2 caching : Get/Set caching

    $das->caching(1);

=cut
sub caching {
  my ($self, $caching) = @_;
  $self->{'caching'}   = $caching if(defined $caching);
  return $self->{'caching'};
}

=head2 callback : Get/Set callback code ref

    $das->callback(sub { });

=cut
sub callback {
  my ($self, $callback) = @_;
  $self->{'callback'}   = $callback if($callback);
  return $self->{'callback'};
}

=head2 basename : Get base URL(s) of service

    $das->basename(optional $dsn);

=cut
sub basename {
  my ($self, $dsn) = @_;
  $dsn           ||= $self->dsn();
  my @dsns         = ref($dsn)?@{$dsn}:$dsn;
  my @res          = ();

  for my $service (@dsns) {
    $service =~ m|(https?://.*/das)/?|;
    push @res, $1 if($1);
  }

  return \@res;
}

=head2 dsn : Get/Set DSN

  $das->dsn("http://das.ensembl.org/das/ensembl1834/"); # give dsn (scalar or arrayref) here if not specified in new()

=cut
sub dsn {
  my ($self, $dsn) = @_;
  if($dsn) {
    if(ref($dsn) eq "ARRAY") {
      $self->{'dsn'} = $dsn;
    } else {
      $self->{'dsn'} = [$dsn];
    }
  }
  return $self->{'dsn'};
}

=head2 dsns : Retrieve information about other sources served from this server.

 Note this call is 'dsns', as differentiated from 'dsn' which is the current configured source

  my $src_data = $das->dsns();

=cut
sub dsns {
  my ($self, $query, $opts) = @_;
  $opts                   ||= {};
  $opts->{'use_basename'}   = 1;
  return $self->_generic_request($query, 'dsn', $opts);
}

=head2 entry_points : Retrieve the list of entry_points for this source

  e.g. chromosomes and associated information (e.g. sequence length and version)

  my $entry_points  = $das->entry_points();

=cut
sub entry_points {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'entry_points', $opts);
}

=head2 Types of argument for 'types', 'features', 'sequence' calls:

  Segment Id:
  "1"

  Segment Id with range:
  "1:1,1000"

  Segment Id with range and type:
  {
    'segment' => "1:1,1000",
    'type'    => 'exon',
  }

  Multiple Ids with ranges and types:
  [
    {
      'segment' => "1:1,1000",
      'type'    => 'exon',
    },
    {
      'segment' => "2:1,1000",
      'type'    => 'exon',
    },
  ]

  See DAS specifications for other parameters

=cut

=head2 types : Find out about different data types available from this source

  my $types         = $das->types(); # takes optional args - see DAS specs

 Retrieve the types of data available for this source
 e.g. 32k_cloneset, karyotype, swissprot

=cut
sub types {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'type(s)', $opts);
}

=head2 features : Retrieve features from a segment

   e.g. clones on a chromosome

  #########
  # Different ways to fetch features -
  #
  my $feature_data1 = $das->features("1:1,100000");
  my $feature_data2 = $das->features(["1:1,100000", "2:20435000,21435000"]);
  my $feature_data3 = $das->features({
                                      'segment' => "1:1,1000",
                                      'type'    => "karyotype",
                                      # optional args - see DAS Spec
                                     });
  my $feature_data4 = $das->features([
                                      {'segment' => "1:1,1000000",'type' => 'karyotype',},
                                      {'segment' => "2:1,1000000",},
                                     ]);

  #########
  # Feature fetch with callback
  #
  my $callback = sub {
		      my $struct = shift;
	              print STDERR Dumper($struct);
	             };
  # then:
  $das->callback($callback);
  $das->features("1:1,1000000");

  # or:
  $das->features("1:1,1000000", $callback);

  # or:
  $das->features(["1:1,1000000", "2:1,1000000", "3:1,1000000"], $callback);

=cut
sub features {
  my ($self, $query, $callback, $opts) = @_;
  if(ref($callback) eq "HASH" && !defined($opts)) {
    $opts = $callback;
    undef($callback);
  }
  $self->{'callback'} = $callback if($callback);
  return $self->_generic_request($query, 'feature(s)', $opts);
}

=head2 sequence : Retrieve sequence data for a segment (probably dna or protein)

  my $sequence      = $das->sequence("2:1,1000"); # segment:start,stop (e.g. chromosome 2, bases 1 to 1000)

=cut
sub sequence {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'sequence', $opts);
}

=head2 stylesheet : Retrieve stylesheet data

  my $style_data    = $das->stylesheet();
  my $style_data2   = $das->stylesheet($callback);

=cut
sub stylesheet {
  my ($self, $callback, $opts) = @_;
  if(ref($callback) eq "HASH" && !defined($opts)) {
    $opts = $callback;
    undef($callback);
  }
  $self->{'callback'}   = $callback if($callback);
  return $self->_generic_request(undef, 'stylesheet', $opts);
}

#########
# Private methods
#

#########
# Build the query URL; perform an HTTP fetch; drop into the recursive parser; apply any post-processing
#
sub _generic_request {
  my ($self, $query, $fname, $opts) = @_;
  $opts       ||= {};
  my $ref       = {};
  my $dsn       = $opts->{'use_basename'}?$self->basename():$self->dsn();
  my @bn        = @{$dsn};
  my $results   = {};
  my @queries   = ();
  my $reqname   = $fname;
  $reqname      =~ s/[\(\)]//g;
  ($fname)      = $fname =~ /^([a-z_]+)/;
  my $attr      = $ATTR->{$fname};

  if($query) {
    if(ref($query) eq "HASH") {
      push @queries, join(";", map { "$_=$query->{$_}" } grep { $query->{$_} } @{$OPTS->{$fname}});
#      $self->{'callback'} = $query->{'callback'} if($query->{'callback'});

    } elsif(ref($query) eq "ARRAY") {
      if(ref($query->[-1]) eq "CODE") {
	$self->callback($query->[-1]);
	pop @{$query};
      }

      if(ref($query->[0]) eq "HASH") {
	push @queries, map {
	  my $q = $_;
	  join(";", map { "$_=$q->{$_}" } grep { $q->{$_} } @{$OPTS->{$fname}});
	} @{$query};
      } else {
	push @queries, map { "segment=$_"; } @{$query};
      }
    } else {
      push @queries, "segment=$query";
    }
  } else {
    push @queries, "";
  }

  for my $bn (@bn) {
    for my $request (map { "$bn/$reqname?$_" } @queries) {
      if($self->{'caching'} && $self->{'_cache'}->{$request}) {
	#########
	# the key has to be present, but the '0' callback will be ignored by _fetch
	#
	$results->{$request} = 0;
	next;
      }

      $results->{$request} = [];
      $ref->{$request} = sub {
	my $data                     = shift;
	$self->{'data'}->{$request} .= $data;

	unless($self->{'currentsegs'}->{$request}) {
	  $self->{'currentsegs'}->{$request} = [];
	  $data   =~ s/(<segment[^>]+?>)/&_parse_branch($self, $request, $self->{'currentsegs'}->{$request}, $ATTR->{'_segment'}, $1, 0)/smegi;
	}

	$DEBUG and print STDERR qq(invoking _parse_branch for $fname\n);

	my $pat = qr!(<$fname.*?/$fname>|<$fname[^>]+/>)!smi;
	while($self->{'data'}->{$request} =~ /$pat/) {
	  &_parse_branch($self, $request, $results->{$request}, $attr, $1, 1);
	  $self->{'data'}->{$request}     =~ s/$pat//;
	}

	$DEBUG and print STDERR qq(completed _parse_branch\n);
	return;
      };
    }
  }

  $self->_fetch($ref, $opts->{'headers'});
  $DEBUG and print STDERR qq(Content retrieved\n);

  #########
  # postprocessing (hack!)
  #
  if($fname eq "entry_points") {
    $DEBUG and print STDERR qq(Running postprocessing for entry_points\n);
    for my $s (keys %$results) {
      for my $r (@{$results->{$s}}) {
	delete $r->{'entry_points'};
      }
    }
  }

  #########
  # deal with caching
  #
  if($self->{'caching'}) {
    $DEBUG and print STDERR qq(Performing cache handling\n);
    for my $s (keys %$results) {
      $DEBUG and print STDERR qq(CACHE HIT for $s\n) if(!$results->{$s});
      $results->{$s}          ||= $self->{'_cache'}->{$s};
      $self->{'_cache'}->{$s} ||= $results->{$s};
    }
  }

  return $results;
}

#########
# Set up the parallel HTTP fetching
# This uses our LWP::Parallel::UserAgent subclass which has better proxy handling
#
sub _fetch {
  my ($self, $url_ref, $headers) = @_;
  $self->{'ua'}                ||= Bio::DasLite::UserAgent->new(
								'http_proxy' => $self->http_proxy(),
							       );
  $self->{'ua'}->initialize();
  $self->{'ua'}->max_req($self->max_req()||$MAX_REQ);
  $self->{'statuscodes'}          = {};
  $headers                      ||= {};
  $headers->{'X-Forwarded-For'} ||= $ENV{'HTTP_X_FORWARDED_FOR'} if($ENV{'HTTP_X_FORWARDED_FOR'});

  for my $url (keys %$url_ref) {
    next unless(ref($url_ref->{$url}) eq "CODE");
    $DEBUG and print STDERR qq(Building HTTP::Request for $url [timeout=$self->{'timeout'}] via $url_ref->{$url}\n);

    my $response = $self->{'ua'}->register(HTTP::Request->new('GET', $url, HTTP::Headers->new(%$headers)), $url_ref->{$url}, $BLK_SIZE);

    $self->{'statuscodes'}->{$url} ||= $response->status_line() if($response);
  }

  $DEBUG and print STDERR qq(Requests submitted. Waiting for content\n);
  eval {
    $self->{'ua'}->wait($self->{'timeout'});
  };

  if($@) {
    warn $@;
#    print STDERR "ua dump:\n", Dumper $self->{'ua'};
  }

  for my $url (keys %$url_ref) {
    next unless(ref($url_ref->{$url}) eq "CODE");

    $self->{'statuscodes'}->{$url} ||= "200";
  }
}

=head2 statuscodes : Retrieve HTTP status codes for request URLs

  my $code         = $das->statuscodes($url);
  my $code_hashref = $das->statuscodes();

=cut
sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};

  if($self->{'ua'}) {
    my $uacodes = $self->{'ua'}->statuscodes();
    for my $k (keys %$uacodes) {
      $self->{'statuscodes'}->{$k} = $uacodes->{$k} if($uacodes->{$k});
    }
  }

  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

=head2 max_req set number of running concurrent requests

  $das->max_req(5);
  print $das->max_req();

=cut
sub max_req {
  my ($self, $max)    = @_;
  $self->{'_max_req'} = $max if($max);
  return $self->{'_max_req'};
}

#########
# Using the $attr structure describing the structure of this branch,
# recursively parse the XML blocks and build the corresponding response data structure
#
sub _parse_branch {
  my ($self, $dsn, $ar_ref, $attr, $blk, $addseginfo, $depth) = @_;
  $depth ||= 0;

  my $ref = {};

  my (@parts, @subparts);
  while(my ($k, $v) = each %$attr) {
    if(ref($v) eq "HASH") {
      push @subparts, $k;
    } else {
      push @parts, $k;
    }
  }

  #########
  # handle groups
  #
  for my $subpart (@subparts) {
    my $subpart_ref  = [];

    my $pat = qr!(<$subpart[^/]+/>|<$subpart[^/]+>.*?/$subpart>)!smi;
    while($blk =~ /$pat/) {
      &_parse_branch($self, $dsn, $subpart_ref, $attr->{$subpart}, $1, 0, $depth+1);
      $blk     =~ s/$pat//;
    }

    $ref->{$subpart} = $subpart_ref if(scalar @{$subpart_ref});

    #########
    # To-do: normalise group data across features here - mostly for 'group' tags in feature responses
    # i.e. merge links, use cached hashrefs (keyed on group id) describing groups to reduce the parsed tree footprint
    #
  }

  my $tmp;

  for my $tag (@parts) {
    my $opts = $attr->{$tag}||[];

    for my $a (@{$opts}) {
      ($tmp)              = $blk =~ m|<$tag[^>]+$a="([^"]+?)"|smi;
      $ref->{"${tag}_$a"} = $tmp if(defined $tmp);
    }

    ($tmp)       = $blk =~ m|<$tag[^>]*>([^<]+)</$tag>|smi;
    if(defined $tmp) {
      $tmp         =~ s/^\s+$//smg;
      $ref->{$tag} = $tmp if(length $tmp);
    }
    $DEBUG and print STDERR " "x($depth*2), qq(  $tag = $tmp\n) if($tmp);
  }

  #########
  # handle multiples of twig elements here
  #
  $blk =~ s!<link\s+href="([^"]+)"[^>]*?>([^<]+)</link>!{
                                                        $ref->{'link'} ||= [];
							push @{$ref->{'link'}}, {
										 'href' => $1,
										 'txt'  => $2,
										};
							""
						       }!smegi;
  $blk =~ s!<note[^>]*?>([^<]+)</note>!{
                                        $ref->{'note'} ||= [];
					push @{$ref->{'note'}}, $1;
					""
				       }!smegi;

  if($addseginfo && $self->{'currentsegs'}->{$dsn} && @{$self->{'currentsegs'}->{$dsn}}) {
    while(my ($k, $v) = each %{$self->{'currentsegs'}->{$dsn}->[0]}) {
      $ref->{$k} = $v;
    }
  }

  push @{$ar_ref}, $ref;
  $DEBUG and print STDERR " "x($depth*2), qq(leaving _parse_branch\n);

  #########
  # only perform callbacks if we're at recursion depth zero
  #
  if($depth == 0 && $self->{'callback'}) {
    $DEBUG and print STDERR " "x($depth*2), qq(executing callback at depth $depth\n);
    $ref->{'dsn'} = $dsn;
    my $callback = $self->{'callback'};
    &$callback($ref);
  }

  return "";
}


1;
__END__


=head1 DESCRIPTION

This module is an implementation of a client for the DAS protocol (XML over HTTP primarily for biological-data).
It requires LWP::Parallel::UserAgent.

=head1 SEE ALSO

DAS Specifications at: http://biodas.org/documents/spec.html

ProServer (A DAS Server implementation) at:
   http://www.sanger.ac.uk/proserver/

The venerable Bio::Das suite (CPAN and http://www.biodas.org/download/Bio::Das/).

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
