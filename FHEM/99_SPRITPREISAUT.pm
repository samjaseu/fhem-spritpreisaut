#########################
#
#  99_SPRITPREISAUT.pm
#


use strict;
use warnings;
use HttpUtils;
use POSIX;
use JSON;
use utf8;
no utf8;



sub SPRITPREISAUT_Initialize($$) {
	my ($hash) = @_;
	
    $hash->{DefFn}      = 'SPRITPREISAUT_Define';
	$hash->{AttrFn}     = 'SPRITPREISAUT_Attr';
	$hash->{SetFn}      = 'SPRITPREISAUT_Set';
}



sub SPRITPREISAUT_Define() {
	my ($hash,$def) = @_;
	my @args = split('[ \t]+', $def);
	
	if(int(@args) < 8) {
		if($args[2] eq "address") {
			return "too few parameters: define <name> SPRITPREISAUT <searchby> <latitude> <longitude> <fuelType> <include> <interval>";
		} elsif($args[2] eq "region") {
			return "too few parameters: define <name> SPRITPREISAUT <searchby> <code> <type> <fuelType> <include> <interval>";
		}
	}
	
	
	my $fuelType = "";
	my $dt       = gettimeofday();
	
	$hash->{ModuleVersion} = "0.2";
	$hash->{DEFINETIME}    = $dt;
	
	$hash->{name}          = $args[0];
	$hash->{searchby}      = $args[2];
	
	if($hash->{searchby} eq "region") {
		$hash->{code}      = $args[3];
		$hash->{type}      = $args[4];
		$hash->{fuelType}  = $args[5];
		$hash->{include}   = $args[6];
		$hash->{Interval}  = $args[7];
		
		$hash->{MainURL}   = "https://api.e-control.at/sprit/1.0/search/gas-stations/by-$hash->{searchby}?code=$hash->{code}&type=$hash->{type}&fuelType=$hash->{fuelType}&includeClosed=$hash->{include}";
	} elsif($hash->{searchby} eq "address") {
		$hash->{latitude}  = $args[3];
		$hash->{longitude} = $args[4];
		$hash->{fuelType}  = $args[5];
		$hash->{include}   = $args[6];
		$hash->{Interval}  = $args[7];
		
		$hash->{MainURL}   = "https://api.e-control.at/sprit/1.0/search/gas-stations/by-$hash->{searchby}?latitude=$hash->{latitude}&longitude=$hash->{longitude}&fuelType=$hash->{fuelType}&includeClosed=$hash->{include}";
	}
	

	if( $hash->{fuelType} eq "DIE" ) { $fuelType = "Diesel"; }
	elsif( $hash->{fuelType} eq "SUP" ) { $fuelType = "Super95"; }
	elsif( $hash->{fuelType} eq "GAS" ) { $fuelType = "Gas"; }

	fhem("attr $hash->{name} userattr stateFormat");
	fhem("attr $hash->{name} stateFormat guenstigster $fuelType :  € location_01_amount bei location_01_name");

	SPRITPREISAUT_GetUpdate($hash);

	return undef;
}


sub SPRITPREISAUT_GetUpdate($) {
	my ($hash) = @_;
	my $name = $hash->{name};
	
	my $nt  = gettimeofday();
	my $fmt = FmtDateTime($nt);
	
	$hash->{TRIGGERTIME}     = $nt;
	$hash->{TRIGGERTIME_FMT} = $fmt;
	
	Log3 $name, 4, "SPRITPREISAUT: GetUpdate called ... (Interval $hash->{Interval})";
	
	SPRITPREISAUT_PerformHttpRequest($hash);
	
	InternalTimer(gettimeofday()+$hash->{Interval}, "SPRITPREISAUT_GetUpdate", $hash);
}


sub SPRITPREISAUT_PerformHttpRequest($)
{
   	my ($hash, $def) = @_;
	my $name  = $hash->{name};
	my $url   = $hash->{MainURL};
	
	my $param = {
		url        => $url,
		timeout    => 5,
		hash       => $hash,
		method     => "GET",
		header     => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.87 Safari/537.36\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
		callback   => \&SPRITPREISAUT_ParseHttpResponse
	};
	
	HttpUtils_NonblockingGet($param);
}


sub SPRITPREISAUT_ParseHttpResponse($) {
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{name};

    if($err ne "") {
        Log3 $name, 3, "error while requesting ".$param->{MainURL}." - $err";
        readingsSingleUpdate($hash, "fullResponse", "ERROR", 0);
    } elsif($data ne "") {
        Log3 $name, 3, "MainURL ".$param->{MainURL}." returned: $data";
		
		my $param = {
			hash	=> $hash,
			data	=> $data
		};
		SPRITPREISAUT_ParseJSONResponse($param);
		
        readingsSingleUpdate($hash, "fullResponse", $data, 0);
    }    
}


sub SPRITPREISAUT_ParseJSONResponse($) {
	my ($param) = @_;
	my $hash = $param->{hash};
	my $data = $param->{data};
	my $name = $hash->{name};
		
	my $decoded = decode_json($data);
	
	# hardcoded 5 items, need length of $decoded array.
	for( my $i = 0; $i < 5; $i++ ) {
		my $j          = $i + 1;
		my $locname    = encode('UTF-8',$decoded->[$i]->{'name'});
		my $locaddress = encode('UTF-8',$decoded->[$i]->{"location"}->{"address"});
		my $loccity    = encode('UTF-8',$decoded->[$i]->{"location"}->{"city"});
		
		readingsSingleUpdate($hash, "location_0".$j."_id", $decoded->[$i]->{'id'}, 0);
		readingsSingleUpdate($hash, "location_0".$j."_name", $locname, 0);
		readingsSingleUpdate($hash, "location_0".$j."_address", $locaddress, 0);
		readingsSingleUpdate($hash, "location_0".$j."_postalcode", $decoded->[$i]->{"location"}->{"postalCode"}, 0);
		readingsSingleUpdate($hash, "location_0".$j."_city", $loccity, 0);
		readingsSingleUpdate($hash, "location_0".$j."_amount", $decoded->[$i]->{"prices"}->[0]->{"amount"}, 0);
	}
	
	return undef;
}



sub SPRITPREISAUT_Set($$$@) {
	my ($hash, $name, $command, @values) = @_;
	my $hash = $defs{$name};
	
	return undef;
}


sub SPRITPREISAUT_Attr($$$$) {
	my ($command, $name, $attribute, $value) = @_;
	my $hash = $defs{$name};
	
	return undef;
}


1;



# Beginn der Commandref

=pod
=item [helper|device|command]
=item summary Kurzbeschreibung in Englisch was SPRITPREISAUT steuert/unterstützt
=item summary_DE Kurzbeschreibung in Deutsch was SPRITPREISAUT steuert/unterstützt

=begin html
 English Commandref in HTML
=end html

=begin html_DE
 Deutsche Commandref in HTML
=end html

=cut
