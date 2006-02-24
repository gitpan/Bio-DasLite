#!/usr/local/bin/perl5.8.0

#This is a first test script to acces the das registry, then to call the different das sources to get the appropriate information.
# Development steps:
# 1. Connect to the Das registry
# 2. Get Sequence and alignment servers
# 3. Get features.

use strict;
use warnings;

use Bio::DasLite;
use Data::Dumper;

my $das = Bio::DasLite->new;


my (@capabilities, @coos_sys); 
push(@capabilities, "sequence", "features");
push(@coos_sys, "Protein Sequence");
my $conf = { 'http_proxy' => 'http://wwwcache.sanger.ac.uk:3128/',
					'capabilities' => \@capabilities,
	    'coordinate_system' => \@coos_sys };

&discoverSources( $das, { 'http_proxy' => 'http://wwwcache.sanger.ac.uk:3128/',
			  'capabilities' => \@capabilities,
			  'coordinate_system' => \@coos_sys });



sub discoverSources{
    my ($self, $config) = @_;

    #We shall see if we have SOAP::Lite installed
    warn ("Unfortunately SOAP::Lite is not install or found:$@\n") unless (eval "require SOAP::Lite");
    if($@){
	warn "\n**** Failed to load SOAP::Lite, therefore I can not discover sources **** \n\n";
    }else{
	#Okay, we have soaplite installed.  Now connect to the DAS registry and get a list of all services
	
	print "Success, lets try and find some sources\n";
	
	my @discovered;
	my $soapCall =
	    SOAP::Lite->service(
				'http://servlet.sanger.ac.uk/dasregistry/services/das'
				. ':das_directory?wsdl' );
	
	#Set up the proxy is we need to
	my $proxy;
	if($self->http_proxy){
	    $proxy = $self->http_proxy;
	}elsif($$config{'proxy'}){
	    print "Setting proxy\n";
	    $proxy = $$config{'proxy'};
	}

	$soapCall->proxy('http://servlet.sanger.ac.uk/dasregistry/services/das', 
			  proxy => ['http' => "$proxy"]) if ($proxy);	
	
	
	#We should be ready to execute the soap call
	my $sources = $soapCall->listServices();
	
	my %cap;
	if($$config{'capabilities'}){
	    %cap = map{$_ => 1}@{$$config{'capabilities'}};
	}
	
	my %coos;
	if($$config{'coordinate_system'}){
	    %coos = map{$_ => 1}@{$$config{'coordinate_system'}};
	}
	
	print Dumper(%cap);
	foreach my $source ( @{$sources} ) {
	    my $add = 0;
	    print ${${$$source{'coordinateSystem'}}[0]}{"category"}."\n";
	    
	    if(%cap && %coos){
		print "Here\n";
		#find source that match both coos-system and capablities
		foreach my $cap (@{$$source{'capabilities'}}){
		    print "$cap\n";
		    if($cap{$cap} && $coos{ ${${$$source{'coordinateSystem'}}[0]}{"category"} }){
			$add = 1;
			print "added\n";
		    }
		}
		
	    }elsif(%coos){
		
	    }elsif(%cap){

	    }else{
		$add =1 ;
	    }
	    if($add){
		print "pushing source dsn\n";
		push(@discovered, $$source{'url'}); 
		last;
	    }
	    last;

	}
	#Now check that we have found something.
	    
	if(@discovered){
	    print "found something\n";
	    my $dsn = $self->dsn;
	    if(ref $dsn eq "ARRAY"){
		
	    }elsif($dsn){
		
	    }
	    #Now push all dsns onto the discovered
	    $self->dsn(\@discovered);   
	}else{
	    
	}
	
	
    }
}
