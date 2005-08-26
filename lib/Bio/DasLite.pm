package Bio::DasLite;
#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    rmp@sanger.ac.uk
# Created:       2005-08-23
# Last Modified: 2005-08-25
#
use strict;
use warnings;
use Bio::DasLite::UserAgent;
use HTTP::Request;

our $DEBUG    = 0;
our $VERSION  = '0.03';
our $BLK_SIZE = 8192;

#########
# $ATTR contains information about document structure - tags, attributes and subparts
# This is split up by call to reduce the number of tag passes for each response
#
our $ATTR     = {
		 'feature'      => {
				    'feature'      => [qw(id label)],
				    'method'       => [qw(id)],
				    'type'         => [qw(id category reference subparts superparts)],
				    'target'       => [qw(id start stop)],
				    'start'        => [],
				    'end'          => [],
				    'orientation'  => [],
				    'note'         => [],
				    'phase'        => [],
				    'score'        => [],
				    #'link'         => [qw(href)],
				    'group'        => {
						       #'link'    => [qw(href)],
						       'group'   => [qw(id label type)],
						       'note'    => [],
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
				    'segment'      => [qw(id start stop type orientation size subparts)],
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
	    };

#########
# Public methods
#
sub new {
  my ($class, $ref) = @_;
  my $self = {
	      'dsn'     => [],
	      'timeout' => 5,
	      'data'    => {},
	      'caching' => 1,
	     };

  bless $self, $class;

  for my $arg (qw(dsn timeout http_proxy caching)) {
    $self->$arg($ref->{$arg}) if(defined $ref->{$arg} && $self->can($arg));
  }

  return $self;
}

sub http_proxy {
  my ($self, $proxy)    = @_;
  $self->{'http_proxy'} = $proxy if($proxy);
  return $self->{'http_proxy'};
}

sub timeout {
  my ($self, $timeout) = @_;
  $self->{'timeout'} = $timeout if($timeout);
  return $self->{'timeout'};
}

sub caching {
  my ($self, $caching) = @_;
  $self->{'caching'}   = $caching if(defined $caching);
  return $self->{'caching'};
}

sub basename {
  my ($self, $dsn) = @_;
  $dsn           ||= $self->dsn();
  my @dsns         = ref($dsn)?@{$dsn}:$dsn;
  my @res          = ();

  for my $service (@dsns) {
    $service =~ m|(https?://.*?/das)|;
    push @res, $1 if($1);
  }

  return \@res;
}

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

#########
# Note this call is 'dsns', as differentiated from 'dsn' which is the current configured source
#
sub dsns {
  my ($self, $query) = @_;
  return $self->_generic_request($query, 'dsn', 'use_basename' => 1);
}

#########
# Retrieve the list of entry_points for this source
# e.g. chromosomes or contigs
#
sub entry_points {
  my ($self, $query) = @_;
  return $self->_generic_request($query, 'entry_points');
}

#########
# Types of argument for 'types', 'features', 'sequence' calls:
# "1"
# "1:1,1000"
# {'segment' => "1:1,1000", 'type' => 'exon'}
# [{'segment' => "1:1,1000", 'type' => 'exon'}, {'segment' => "2:1,1000", 'type' => 'exon'}]
#
# See DAS specifications for other parameters
#

#########
# Retrieve the types of data available for this source
# e.g. 32k_cloneset, karyotype, swissprot
#
sub types {
  my ($self, $query) = @_;
  return $self->_generic_request($query, 'type(s)');
}

#########
# Retrieve features from a segment
# e.g. clones on a chromosome
#
sub features {
  my ($self, $query) = @_;
  return $self->_generic_request($query, 'feature(s)');
}

#########
# Retrieve sequence data for a segment
# e.g. chromosome 1 bases 1-1000
#
sub sequence {
  my ($self, $query) = @_;
  return $self->_generic_request($query, 'sequence');
}

#########
# Private methods
#

#########
# Build the query URL; perform an HTTP fetch; drop into the recursive parser; apply any post-processing
#
sub _generic_request {
  my ($self, $query, $fname, %opts) = @_;
  my $ref            = {};
  my $dsn            = $opts{'use_basename'}?$self->basename():$self->dsn();
  my @bn             = @{$dsn};
  my $results        = {};
  my @queries        = ();
  my $reqname        = $fname;
  $reqname           =~ s/[\(\)]//g;
  ($fname)           = $fname =~ /^([a-z_]+)/;
  my $attr           = $ATTR->{$fname};

  if($query) {
    if(ref($query) eq "HASH") {
      push @queries, join(";", map { "$_=$query->{$_}" } grep { $query->{$_} } @{$OPTS->{$fname}});

    } elsif(ref($query) eq "ARRAY") {
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
	$self->{'data'}->{$request}  =~ s!(<$fname.*?/$fname>|<$fname[^>]+/>)!&_parse_branch($self, $request, $results->{$request}, $attr, $1)!smieg;
	return;
      };
    }
  }
  $self->_fetch($ref);

  #########
  # postprocessing (hack!)
  #
  if($fname eq "entry_points") {
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
  my ($self, $url_ref) = @_;
  $self->{'ua'}      ||= Bio::DasLite::UserAgent->new(
						      'proxy' => $self->http_proxy(),
						     );
  $self->{'ua'}->initialize();

  for my $url (keys %$url_ref) {
    next unless(ref($url_ref->{$url}) eq "CODE");
    $DEBUG and print STDERR qq(Building HTTP::Request for $url [timeout=$self->{'timeout'}]\n);
    $self->{'ua'}->register(HTTP::Request->new(GET => $url), $url_ref->{$url}, $BLK_SIZE);
  }
  $self->{'ua'}->wait($self->{'timeout'});
}

#########
# Using the $attr structure describing the structure of this branch,
# recursively parse the XML blocks and build the corresponding response data structure
#
sub _parse_branch {
  my ($self, $dsn, $ar_ref, $attr, $blk) = @_;
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
    $blk             =~ s!(<$subpart[^/]+/>|<$subpart[^/]+>.*?/$subpart>)!&_parse_branch($self, $dsn, $subpart_ref, $attr->{$subpart}, $1)!smieg;
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
      ($tmp)              = $blk =~ m|<$tag[^>]+$a="([^"]+)"|smi;
      $ref->{"${tag}_$a"} = $tmp if($tmp);
    }

    ($tmp)       = $blk =~ m|<$tag[^>]*>([^<]+)</$tag|smi;
    $ref->{$tag} = $tmp if($tmp);
  }

  #########
  # handle multiples of twig elements here
  #
  $blk =~ s!<link\s+href="([^"]+)"[^>]*?>([^<]+)</link!{
                                                        $ref->{'link'} ||= [];
							push @{$ref->{'link'}}, {
										 'href' => $1,
										 'txt'  => $2,
										};
						       }!smieg;

  push @{$ar_ref}, $ref;
  return "";
}


1;
__END__

=head1 NAME

Bio::DasLite - Perl extension for the DAS (HTTP+XML) Protocol (http://biodas.org/)

=head1 SYNOPSIS

  use Bio::DasLite;

  my $das = Bio::DasLite->new({
			         'timeout'    => 60,                                       # optional timeout in seconds
                                 'dsn'        => "http://das.ensembl.org/das/ensembl1834", # optional DSN (scalar, or arrayref)
                                 'http_proxy' => "http://webcache.local.com:3128",         # optional http proxy
			        });

  $das->dsn("http://das.ensembl.org/das/ensembl1834/"); # give dsn (scalar or arrayref) here if not specified in new()

  #########
  # Retrieve other sources from the same service
  #
  my $src_data      = $das->dsns();

  #########
  # Retrieve entry_points, e.g. chromosomes and associated information (e.g. sequence length and version)
  #
  my $entry_points  = $das->entry_points();

  #########
  # Retrieve sequence data (probably dna or protein)
  #
  my $sequence      = $das->sequence("2:1,1000"); # segment:start,stop (e.g. chromosome 2, bases 1 to 1000)

  #########
  # Find out about different data types available from this source
  #
  my $types         = $das->types(); # takes optional args - see DAS specs

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
