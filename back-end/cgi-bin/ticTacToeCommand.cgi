#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::UNIX;
use POSIX;

use lib "/home/jfustos/perl5/share/perl5";
use lib "/home/jfustos/perl5/lib64/perl5";
use lib "/home/jfustos/perl5/lib/perl5";
use CGI;
use JSON;

use lib "/home/jfustos/EECS448/ticTacToe";

require "modules/Conf.pm";
require "modules/Report.pm";

my $DEBUG;

$| = 1;

### Start loging
my $conf = Conf::get();
my $reporter = Report::start( $conf->{'logFile'} );

my $cgi = CGI->new;

unless ( ( defined $cgi->request_method ) && (  $cgi->request_method eq 'POST' ) )
{
	preGameDie( "Request must be POST" );
}

unless ( defined $cgi->param("POSTDATA"))
{
	preGameDie( "No post data found!!" );
}


### get the encoded request.
my $myInput = $cgi->param("POSTDATA");
$reporter->{'log'}->( "Post data was |$myInput|" );
chomp( $myInput );

my $client = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Peer => $conf->{'socketFile'},
);

if( $client )
{
	$client->autoflush( 1 );
	$client->blocking( 0 );
	
	print "Status: 200 OK\n";
	print "Content-Type: application/json; charset=ISO-8859-1\r\n";
	print "Transfer-Encoding: chunked\r\n";
	print "\r\n";

	$myInput = unTaint( $myInput );
	$myInput .= "\n";
	
	my $myInputLength = length $myInput;
	
	unless( $myInputLength > 0 )
	{
		gameDie("Command sent had 0 length!!!");
	}
	
	$reporter->{'log'}->( "Trying to send |$myInput|." );
	
	my $timeOut = 5;
	while( 1 )
	{
		if( $timeOut-- <= 0 )
		{
			gameDie("Timed out trying to send |$myInput|. Was not completely sent. Dieing.");
		}
		
		my $byteSent = $client->send( $myInput, 0 );
		
		unless( ( defined $byteSent ) && ( $byteSent > 0 ) )
		{
			### no characters were sent, see if we can recover from this.
			if( !(defined $byteSent) && (
					( $! == POSIX::EAGAIN ) || ( $! == POSIX::EWOULDBLOCK ) || ( $! == POSIX::EINTR ) 
				)
			)
			{
				$reporter->{'log'}->( "Trying to send |$myInput| again, error was $!." );
			}
			else
			{
				gameDie("Unrecoverable error or pipe closed trying to send |$myInput|.");
			}
		}
		else
		{
			### message might have sent but maybe only partially, so try to send rest.
			if( $byteSent >= $myInputLength )
			{
				$reporter->{'log'}->( "Successfully sent |$myInput|. Message complete." );
				last;
			}
			
			$myInput = substr $myInput, $byteSent;
			$myInputLength = length $myInput;
			$reporter->{'log'}->( "Successfully sent |$byteSent| bytes trying to send rest |$myInput|." );
			$timeOut = 5;
		}
		
		select( undef, undef, undef, 0.1 );
	}

	$reporter->{'log'}->( "Waiting for responses." );
	
	$timeOut = 200;
	my $recvMessage = '';
	my $pastMessage = '';
	while( 1 )
	{
		if( $timeOut-- <= 0 )
		{
			gameDie("Timed out trying to get a full message from game. Only got |$pastMessage|.");
		}
		
		my $byteRecv = $client->recv( $recvMessage, POSIX::BUFSIZ, 0 );
		
		unless( ( defined $byteRecv ) && ( defined $recvMessage ) && ( length $recvMessage ) )
		{
			### no characters were recv, see if we can recover from this.
			if( !(defined $byteRecv) && (
					( $! == POSIX::EAGAIN ) || ( $! == POSIX::EWOULDBLOCK ) || ( $! == POSIX::EINTR ) 
				)
			)
			{
				$reporter->{'log'}->( "Recoverable error, try again timeLeft |$timeOut|, error was $!." ) if $DEBUG;
			}
			else
			{
				$reporter->{'log'}->( "Unrecoverable error or pipe closed. End this transmission." );
				last;
			}
		}
		else
		{
			### We got something back, check to see if full message, if it is, send it out.
			$pastMessage .= $recvMessage;
			$reporter->{'log'}->( "Got more bytes back, buffer is now |$pastMessage|." );
			
			while( $pastMessage =~ s/(.*?)\n// )
			{
				my $command = $1;
				$reporter->{'log'}->( "Got back complete commmand from server |$command|." );
				chunckMessage( $command );
				$timeOut = 200;
			}
		}
		
		select( undef, undef, undef, 0.1 );
	}
	
	chunckEnd();
	
	$client->close();
}
else
{
	preGameDie( "Could not open client says: $!" );
}

exit 0;

sub chunckMessage
{
	my $message = shift;
	
	$message = unTaint($message);
	
	$message = "<==$message==>";
	
	my $message_len = length $message;
	$message_len = sprintf( "%x", $message_len);
	print "$message_len\r\n";
	print "$message\r\n";
	
	return;
}

sub chunckEnd
{
	select(undef, undef, undef, 0.1);
	print "0\r\n";
	print "\r\n";
}

sub unTaint
{
	my $message = shift;
	
	chomp($message);
	$message =~ s/\n/\*/g;
	$message =~ s/<==/<\*=/g;
	$message =~ s/==>/=\*>/g;
	
	return $message;
}

sub preGameDie
{
	my $message = shift;
	
	print "Status: 503 Game might be down\n";
	print "Content-Type: application/json; charset=ISO-8859-1\r\n";
	print "Transfer-Encoding: chunked\r\n";
	print "\r\n";
	
	gameDie( $message );
}

sub gameDie
{
	my $message = shift;
	my $socket = shift;
	
	if( $socket )
	{
		$socket->close();
	}
	
	$message = unTaint($message);
	
	$reporter->{'log'}->( $message, 'ERROR' );
	
	my $encodedOut = encode_json ( { name => "ERROR", message => $message} );
	chunckMessage( $encodedOut );
	chunckEnd();
	
	exit(0);
}
