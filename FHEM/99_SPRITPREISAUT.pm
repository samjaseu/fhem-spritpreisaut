##################################################
#
#  99_SPRITPREISAUT.pm
#
#  Wegscheider IT-Services
#  contact@samjas.eu
#
#
##################################################
#
# Changelog:
#       0.1  first version - static readin with region code only
#       0.2  added support for by-address search with longitude/latitude.
#       0.3  added enableControlSet support - set interval, reread, start and stop.
#       0.4  added attribute 'spritattrlist' to use as variable list for more reading infos.
#            supported values: latitude,longitude,telephone,fax,mail,website
#


use strict;
use warnings;
use HttpUtils;
use JSON;
use Encode qw(
		decode
		encode
);


my $moduleversion = "0.4";


# Initialize
##################################################
sub SPRITPREISAUT_Initialize($$) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'SPRITPREISAUT_Define';
	$hash->{SetFn}      = 'SPRITPREISAUT_Set';
	$hash->{GetFn}      = 'SPRITPREISAUT_Get';
	$hash->{AttrFn}     = 'SPRITPREISAUT_Attr';
	$hash->{UndefFn}    = 'SPRITPREISAUT_Undef';

	my @attrList = qw(
		enableControlSet:0,1
		spritattrlist:textField
  );
  $hash->{AttrList} = join(" ", @attrList)." $readingFnAttributes";

	my @spritattrliste = qw(
		latitude
		longitude
		telephone
		fax
		mail
		website
	);
}


# Define
##################################################
sub SPRITPREISAUT_Define() {
	my ($hash,$def) = @_;
	my @args = split('[ \t]+', $def);

	if(int(@args) < 8) {
		if($args[2] eq "address") {
			return "too few parameters: define <name> SPRITPREISAUT <searchby>",
						 " <latitude> <longitude> <fuelType> <include> <interval>";
		} elsif($args[2] eq "region") {
			return "too few parameters: define <name> SPRITPREISAUT <searchby>",
						 " <code> <type> <fuelType> <include> <interval>";
		}
	}

	my $fuelType           = "";
	my $dt                 = gettimeofday();

	$hash->{ModuleVersion} = $moduleversion;
	$hash->{DEFINETIME}    = $dt;

	$hash->{name}          = $args[0];
	$hash->{searchby}      = $args[2];

	if($hash->{searchby} eq "region") {
		$hash->{code}        = $args[3];
		$hash->{type}        = $args[4];
		$hash->{fuelType}    = $args[5];
		$hash->{include}     = $args[6];
		$hash->{Interval}    = $args[7];

		$hash->{MainURL}     = "https://api.e-control.at/sprit/1.0/search/gas-stations/by-$hash->{searchby}?code=$hash->{code}&type=$hash->{type}&fuelType=$hash->{fuelType}&includeClosed=$hash->{include}";
	} elsif($hash->{searchby} eq "address") {
		$hash->{latitude}    = $args[3];
		$hash->{longitude}   = $args[4];
		$hash->{fuelType}    = $args[5];
		$hash->{include}     = $args[6];
		$hash->{Interval}    = $args[7];

		$hash->{MainURL}     = "https://api.e-control.at/sprit/1.0/search/gas-stations/by-$hash->{searchby}?latitude=$hash->{latitude}&longitude=$hash->{longitude}&fuelType=$hash->{fuelType}&includeClosed=$hash->{include}";
	}

	if( $hash->{fuelType} eq "DIE" ) { $fuelType = "Diesel"; }
	elsif( $hash->{fuelType} eq "SUP" ) { $fuelType = "Super95"; }
	elsif( $hash->{fuelType} eq "GAS" ) { $fuelType = "Gas"; }

	fhem("attr $hash->{name} userattr stateFormat");
	fhem("attr $hash->{name} stateFormat guenstigster $fuelType :  € location_01_amount bei location_01_name");


	SPRITPREISAUT_SetTimer($hash, 2);


  $hash->{".getList"}          = "";
  $hash->{".setList"}          = "";
  $hash->{".updateHintList"}   = 1;

	return undef;
}


# Set
##################################################
sub SPRITPREISAUT_Set($@) {
		my ($hash, @args) = @_;
		if(@args < 2) { return "\"set SPRITPREISAUT\" needs at least an argument"; }

		my ($name, $setName, @setValArr) = @args;
		my $setVal = (@setValArr ? join(' ', @setValArr) : "");
		my (%rmap, $setNum, $setOpt, $rawVal);

		if(AttrVal($name, "enableControlSet", undef)) {
			my $error = SPRITPREISAUT_ControlSet($hash, $setName, $setVal);

			return undef if (defined($error) && $error eq "0");
			return $error if ($error);
		}

		foreach my $aName (keys %{$attr{$name}}) {
			if ($aName =~ /^set([0-9]+)Name$/) {
					if ($setName eq $attr{$name}{$aName}) {
							$setNum = $1;
					}
			}
		}

		if(!defined ($setNum)) {
				if($hash->{".updateHintList"}) { SPRITPREISAUT_UpdateHintList($hash); }

				return "Unknown argument $setName, choose one of " . $hash->{".setList"};
		}

		return undef;
}


# Get
##################################################
sub SPRITPREISAUT_Get($@) {
	my ($hash, @args) = @_;
	if ( @args < 2 ) { return "\"get SPRITPREISAUT\" needs at least an argument" };

	my ($name, $getName, @getValArr) = @args;
	my $getVal = (@getValArr ? join(' ', @getValArr) : "");
	my $getNum;

	if(!defined ($getNum)) {
		if($hash->{".updateHintList"}) { SPRITPREISAUT_UpdateHintList($hash) };

		return "Unknown argument $getName, choose one of " . $hash->{".getList"};
	}
}


# Attr
##################################################
sub SPRITPREISAUT_Attr($$$$) {
	my ($command, $name, $attribute, $value) = @_;
	my $hash = $defs{$name};

	if($attribute =~ /^[gs]et/ || $attribute eq "enableControlSet") {
		$hash->{".updateHintList"} = 1;
  }

	if($attribute eq "spritattrlist") {
		SPRITPREISAUT_SetTimer($hash, 2);
	}

	return undef;
}


# Undef
##################################################
sub SPRITPREISAUT_Undef($$$$) {
	my ($hash, $arg) = @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer ("timeout:$name");
	RemoveInternalTimer ("queue:$name");
	RemoveInternalTimer ("update:$name");

	return undef;
}





# PerformHttpRequest
##################################################
sub SPRITPREISAUT_PerformHttpRequest($) {
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


# ParseHTTPResponse
##################################################
sub SPRITPREISAUT_ParseHttpResponse($) {
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{name};

    if($err ne "") {
        Log3 $name, 3, "error while requesting " . $param->{url} . " - $err";
        readingsSingleUpdate($hash, "fullResponse", "ERROR", 0);
    } elsif($data ne "") {
				my $param = {
					hash	=> $hash,
					data	=> $data
				};

				readingsSingleUpdate($hash, "fullResponse", $data, 0);
				SPRITPREISAUT_ParseJSONResponse($param);
    }
}


# ParseJSONResponse
##################################################
sub SPRITPREISAUT_ParseJSONResponse($) {
	my ($param) = @_;
	my $hash = $param->{hash};
	my $data = $param->{data};
	my $name = $hash->{name};

  my $readingstimestamp = ReadingsTimestamp($name, "fullResponse", "0000-00-00 00:00:00");
	my $decoded = decode_json($data);

	# hardcoded 5 items, max. results with price amount.
	for( my $i = 0; $i < 5; $i++ ) {
		my $j          = $i + 1;
		my $locname    = encode('UTF8',$decoded->[$i]->{'name'});
		my $locaddress = encode('UTF8',$decoded->[$i]->{'location'}->{'address'});
		my $loccity    = encode('UTF8',$decoded->[$i]->{'location'}->{'city'});

		readingsSingleUpdate($hash, "location_0".$j."_id", $decoded->[$i]->{'id'}, 0);
		readingsSingleUpdate($hash, "location_0".$j."_name", $locname, 0);
		readingsSingleUpdate($hash, "location_0".$j."_address", $locaddress, 0);
		readingsSingleUpdate($hash, "location_0".$j."_postalcode", $decoded->[$i]->{'location'}->{'postalCode'}, 0);
		readingsSingleUpdate($hash, "location_0".$j."_city", $loccity, 0);
		readingsSingleUpdate($hash, "location_0".$j."_amount", $decoded->[$i]->{'prices'}->[0]->{'amount'}, 0);

		SPRITPREISAUT_DeleteOldReadings($hash, $readingstimestamp);

		if(AttrVal($name, 'spritattrlist', undef)) {
			my @spritAttrVals = split(',', AttrVal($name, 'spritattrlist', undef));
			foreach my $spritAttrVal (@spritAttrVals) {
				my $AttrReadingVal = "";
				given($spritAttrVal) {
					when($_ eq "latitude") {
						$AttrReadingVal = $decoded->[$i]->{'location'}->{'latitude'};
					}
					when($_ eq "longitude") {
						$AttrReadingVal = $decoded->[$i]->{'location'}->{'longitude'};
					}
					when($_ eq "telephone") {
						$AttrReadingVal = $decoded->[$i]->{'contact'}->{'telephone'};
					}
					when($_ eq "fax") {
						$AttrReadingVal = $decoded->[$i]->{'contact'}->{'fax'};
					}
					when($_ eq "mail") {
						$AttrReadingVal = $decoded->[$i]->{'contact'}->{'mail'};
					}
					when($_ eq "website") {
						$AttrReadingVal = $decoded->[$i]->{'contact'}->{'website'};
					}
					default {
						readingsSingleUpdate($hash, "error_attribute_".$spritAttrVal, "Attribut 'spritattrlist' unterstützt Value '".$spritAttrVal."' NICHT!", 0);
						$AttrReadingVal = "";
					}
				}
				readingsSingleUpdate($hash, "location_0".$j."_".$spritAttrVal, $AttrReadingVal, 0) if ($AttrReadingVal);
			}
		}

	} # for

	return undef;
}


# UpdateHintList
##################################################
sub SPRITPREISAUT_UpdateHintList($) {
	my ($hash) = @_;
	my $name = $hash->{name};

	$hash->{".getlist"} = "";
	if (AttrVal($name, "enableControlSet", undef)) {
        $hash->{".setList"} = "interval reread:noArg stop:noArg start:noArg ";
    } else {
        $hash->{".setList"} = "";
    }

	return undef;
}


# ControlSet
##################################################
sub SPRITPREISAUT_ControlSet($$$) {
    my ($hash, $setName, $setVal) = @_;
    my $name = $hash->{name};

		my $minimumInterval = 5;

    if ($setName eq 'interval') {
        if (!$setVal) {
            return "No Interval specified";
        } else {
            if (int $setVal > $minimumInterval) {
                $hash->{Interval} = $setVal;
                SPRITPREISAUT_SetTimer($hash);

                return "0";
            } elsif (int $setVal <= $minimumInterval) {
                return "interval too small - minimum ".$minimumInterval;
            }
        }
    } elsif ($setName eq 'reread') {
        SPRITPREISAUT_GetUpdate("reread:$name");

        return "0";
    } elsif ($setName eq 'stop') {
        RemoveInternalTimer("update:$name");

        $hash->{TRIGGERTIME}     = 0;
        $hash->{TRIGGERTIME_FMT} = "";

        return "0";
    } elsif ($setName eq 'start') {
        SPRITPREISAUT_SetTimer($hash);

        return "0";
    }
    return undef;
}


# GetUpdate
##################################################
sub SPRITPREISAUT_GetUpdate($) {
	my ($calltype, $name) = split(':', $_[0]);
	my $hash = $defs{$name};

	my $now = gettimeofday();
	my $fmt = FmtDateTime($now);
	$hash->{TRIGGERTIME}     = $now;
	$hash->{TRIGGERTIME_FMT} = $fmt;

	Log3 $name, 4, "SPRITPREISAUT: GetUpdate called ... (Interval $hash->{Interval})";

	if ($calltype eq "update") {
			SPRITPREISAUT_SetTimer($hash);
			SPRITPREISAUT_PerformHttpRequest($hash);

			InternalTimer(gettimeofday()+$hash->{Interval}, "SPRITPREISAUT_GetUpdate", $hash);
	}
}


# SetTimer
##################################################
sub SPRITPREISAUT_SetTimer($;$) {
    my ($hash, $start) = @_;
    my $nextTrigger;
    my $name = $hash->{NAME};
    my $now  = gettimeofday();
    $start   = 0 if (!$start);

    if ($hash->{Interval}) {
        if ($hash->{TimeAlign}) {
            my $count = int(($now - $hash->{TimeAlign} + $start) / $hash->{Interval});
            my $curCycle = $hash->{TimeAlign} + $count * $hash->{Interval};
            $nextTrigger = $curCycle + $hash->{Interval};
        } else {
            $nextTrigger = $now + ($start ? $start : $hash->{Interval});
        }

        $hash->{TRIGGERTIME}     = $nextTrigger;
        $hash->{TRIGGERTIME_FMT} = FmtDateTime($nextTrigger);

        RemoveInternalTimer("update:$name");
        InternalTimer($nextTrigger, "SPRITPREISAUT_GetUpdate", "update:$name", 0);
    } else {
       $hash->{TRIGGERTIME}     = 0;
       $hash->{TRIGGERTIME_FMT} = "";
    }
}


# DeleteOldReadings
##################################################
sub SPRITPREISAUT_DeleteOldReadings($$) {
	my ($hash,$timestamp) = @_;
	my $name = $hash->{name};
	my $readings = $hash->{READINGS};
	return if (!$readings);

	foreach my $reading (sort keys %{$readings}) {
		if(ReadingsTimestamp($name, $reading, "0000-00-00 00:00:00") ne $timestamp) {
			readingsDelete($hash, $reading);
		}
	}

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
