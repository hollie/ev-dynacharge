#!/usr/bin/env perl

# PODNAME: ev-dynacharge.pl
# ABSTRACT: Dynamically adapt the charge current of an EV vehicle based on the total house energy balance
# VERSION

use strict;
use warnings;

use Net::MQTT::Simple;
use Log::Log4perl qw(:easy);
use Getopt::Long 'HelpMessage';
use Pod::Usage;
use JSON;

my ($verbose, $mqtt_host, $mqtt_username, $mqtt_password);

# Default values
$mqtt_host = 'broker';

GetOptions(
    'host=s'     => \$mqtt_host,
    'user=s'     => \$mqtt_username,
    'pass=s'     => \$mqtt_password,
    'help|?|h'   => sub { HelpMessage(0) },
    'man'        => sub { pod2usage( -exitstatus => 0, -verbose => 2 )},
    'v|verbose'  => \$verbose,
) or HelpMessage(1);

if ($verbose) {
	Log::Log4perl->easy_init($DEBUG);
} else {
   	Log::Log4perl->easy_init($INFO);
}

# Connect to the broker
my $mqtt = Net::MQTT::Simple->new($mqtt_host) || die "Could not connect to MQTT broker: $!";
INFO "MQTT logger client ID is " . $mqtt->_client_identifier();

# Depending if authentication is required, login to the broker
if($mqtt_username and $mqtt_password) {
    $mqtt->login($mqtt_username, $mqtt_password);
}


# Subscribe to topics:
my $set_topic = 'chargepoint/maxcurrent';
my $timers_topic = 'chargepoint/timer/#';
#   for access to ..timer/boostmode
#                 ..timer/haltmode
my $mode = 'chargepoint/mode';
my $nr_phases_topic = 'chargepoint/nr_of_phases';


my $maxcurrent = 16;
my $nr_of_phases = 3;

$mqtt->subscribe('dsmr/reading/electricity_currently_delivered', \&mqtt_handler);
$mqtt->subscribe('dsmr/reading/electricity_currently_returned',  \&mqtt_handler);
$mqtt->subscribe($timers_topic,  \&mqtt_handler);

my $energy_balance = 0;
my $counter = 0;
my $current = 6;
my $last_sent = 0;
my $boostmode_timer = 0;
my $boostmode_current = 16;

while (1) {
	
	$mqtt->tick();
	
	if ($boostmode_timer > 0) {
		$boostmode_timer--;
		update_loadcurrent($boostmode_current);	
		INFO "++ Current boost charge mode active at $boostmode_current A - " . $boostmode_timer * 10 . " seconds remaining" ;
		$mqtt->publish("chargepoint/status/boostmode_countdown_timer", $boostmode_timer *10);
		my $loopcounter = 0;
		while ($loopcounter < 10) {
			sleep(1);
			$mqtt->tick();
			$loopcounter++;
		}
	} elsif ($counter > 2) {
		
		$counter = 0;
					
		if ($maxcurrent == 0) {
			$current = 0;
			INFO "** Current is set to 0, not charging";
		} else {
			
			if ($energy_balance > 4 && $nr_of_phases == 1 && $current > 15) {
				# Switch to three-phase charging as there is room enough
				INFO "Switching to three-phase charging based on $energy_balance W feed-in energy balance";
				$nr_of_phases = 3;				
			} elsif ($energy_balance < -1 && $nr_of_phases == 3 && $current < 7) {
				INFO "Switching to one-phase charging based on $energy_balance W consumption energy balance";
				$nr_of_phases = 1;				
			} 

			if ($energy_balance > 1.5) {
				$current+=2;
			} elsif ($energy_balance > 0.20) {
				$current ++;
			} elsif ($energy_balance < -1.5) {
				$current-=2;
			} elsif ($energy_balance < -0.22) {
				$current --;
			}
			
			$current = $maxcurrent if ($current > $maxcurrent);
			$current =  6 if ($current < 6);
		
			INFO "** Current is now $current based on balance $energy_balance W";
	
		}
		
		update_loadcurrent($current);	
		$mqtt->publish($nr_phases_topic, $nr_of_phases);	
		sleep(1);
	}
	sleep(1);
}

sub mqtt_handler {
	my ($topic, $data) = @_;


	TRACE "Got '$data' from $topic";
		
	if ($topic =~ /delivered/) {
		return if ($data == 0); # Do not process empty values
		$energy_balance = ($data) * - 1;
	} elsif ($topic =~ /returned/) {
		return if ($data == 0); # Do not process empty values
		$energy_balance = ($data) * 1;
	} elsif ($topic =~ /boostmode/) {
		INFO "Setting boostmode timer to $data seconds";
		$boostmode_timer = $data / 10;
	} elsif ($topic =~ /maxcurrent/) {
		if ($data > 0 && $data < 16) {
			$maxcurrent = $data;
			INFO "Maximum current is now $maxcurrent A";
		} else {
			WARN "Refuse to set invalid maximum current: '$data'";
		}
	} else {
		WARN "Invalid message received from topic " . $topic;
		return;
	}
	
	$counter++;
	DEBUG "Energy balance is now " . $energy_balance . "W";
	
	
}

sub update_loadcurrent {
	
	my $current = shift();
	
	#my $original_float = $current;
    my $network_long = unpack 'L', pack 'f', $current;


    #my $pack_float = pack 'f', $original_float;
    #my $unpack_long = unpack 'L', $pack_float;


    #print $network_long . "\n";


	my $parameters = {
		'value_msb' => $network_long / 2**16,
		'value_lsb' => $network_long % 2**16,
		'current'   => $current
	};

    #my $value_lsb = $network_long % 2**16;
    #my $value_msb = $network_long / 2**16;
    
	#my $client = Device::Modbus::TCP::Client->new( host => '192.168.3.144');
	#my $client = Device::Modbus::TCP::Client->new( host => '192.168.1.142');
	#my $req1 = $client->write_multiple_registers(
	#	unit => 1, address => 1210,
	#	values => [$val2, $val1]);
	#my $req2 = $client->write_multiple_registers(
	#	unit => 2, address => 1210,
    #	values => [$val2, $val1]);
	#
	#$client->send_request($req1) || die "Send error: $!";
	#$client->send_request($req2) || die "Send error: $!";
	#sleep(5);
	#$client->disconnect();
	
	# Create the json struct
	my $json = encode_json($parameters);
	$mqtt->publish($set_topic, $json);
	
}

=head1 NAME

ev-dynacharge.pl - Dynamically charge an electric vehicle based on the energy budget of the house

=head1 SYNOPSIS

    ./ev-dynacharge.pl [--host <MQTT server hostname...> ]
    
=head1 DESCRIPTION

This script allows to dynamically steer the charging process of an electric vehicle. It fetches energy 
consumption values over MQTT and based on the balance and the selected operating mode it will set the 
charge current of the chargepoint where the vehicle is connected to.

This is very much a work in progress, additional documentation and howto information will be added
after the intial field testing is done.

=head1 Using docker to run this script in a container

This repository contains all required files to build a minimal Alpine linux container that runs the script.
The advantage of using this method of running the script is that you don't need to setup the required Perl
environment to run the script, you just bring up the container.

To do this check out this repository, configure the MQTT broker host, username and password in the C<.env> file and run:

C<docker compose up -d>.

=head1 Updating the README.md file

The README.md file in this repo is generated from the POD content in the script. To update it, run

C<pod2github bin/ev-dynacharge.pl E<gt> README.md>

=head1 AUTHOR

Lieven Hollevoet C<hollie@cpan.org>

=head1 LICENSE

CC BY-NC-SA

=cut
