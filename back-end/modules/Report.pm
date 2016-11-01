package Report;

use strict;
use warnings;

use POSIX qw(strftime);

my $logger;

sub start
{
	my $logFile = shift;
	
	unless (   open( $logger, ">>", $logFile )   )
	{
		print "Cannot open log file |$logFile|: $!";
		exit 1;
	}
	
	my $std_back = select( $logger );
	$| = 1;
	select( $std_back );
	
	myLog( "Starting." );
	
	return {
		log	=> \&myLog,
	};
}

sub myLog
{
    my $message = shift;
	$message = "Hey no message passed to myLog" unless defined $message;
    my $error = shift;
	my $myDie = shift;
    $error = ( defined $error ) ? "ERROR :: " : "";
    my $dateTime = strftime "%F %T", localtime();
    print $logger "${dateTime} :: $$ :: ${0} :: ${error}${message}.\n\n";
	
	if( (defined $myDie) && ($myDie eq "DIE") )
	{
		exit 1;
	}
	
    return;
}

1;
