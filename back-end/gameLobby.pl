#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::UNIX;
use IO::Select;
use POSIX;

use lib "/home/jfustos/perl5/share/perl5";
use lib "/home/jfustos/perl5/lib64/perl5";
use lib "/home/jfustos/perl5/lib/perl5";

use JSON;

use lib "/home/jfustos/EECS448/ticTacToe";

require "modules/Conf.pm";
require "modules/Report.pm";
require "modules/Command.pm";
require "modules/GameUtil.pm";

my $DEBUG;

### Start loging
my $conf = Conf::get();
my $reporter = Report::start( $conf->{'logFile'} );
Command::setReporter( $reporter );

my $command_streams = Command::getCommandStreams();

my $frameStep = 0.1;

my $gameState = "Waiting";
my $waitDisplayRow = 0;
my $waitDisplayCol = 0;
my $waitDisplayXO = "X";
my $turn = 'NO_ONE';
my $prevStart;
my $winner = 'NO_ONE';
my $victoryFrame = 0;
my @gameBoard = ( 
	[ '_', '_', '_' ], 
	[ '_', '_', '_' ], 
	[ '_', '_', '_' ] 
);

my @winBoard = ( 
	[ '_', '_', '_' ], 
	[ '_', '_', '_' ], 
	[ '_', '_', '_' ] 
);

my @pendingReads = ();
my @outStream = ();
my %players = ( 
	P1 => { streams => [], timeout => 0, wins => 0, losses => 0, ties => 0, name => 'P1' }, 
	P2 => { streams => [], timeout => 0, wins => 0, losses => 0, ties => 0, name => 'P2' },
);

my %game = (
	state     => \$gameState, 		turn      => \$turn, 		
	prevStart => \$prevStart,		winner    => \$winner,
	board     => \@gameBoard,		winBoard  => \@winBoard,
	players   => \%players,			gameOver  => \&gameOver,
	updateGameInfo => \&updateGameInfo,
	outStream => \@outStream,		DEBUG     => $DEBUG,
	reporter  => $reporter,
);

my $server = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Local => $conf->{'socketFile'},
	Listen => 10,
);

unless( $server )
{
	$reporter->{'log'}->( "Could not open UNIX socket says: $!", "ERROR", "DIE" );
}

$server->autoflush( 1 );
my $sel = IO::Select->new( $server );

my $frame = 0;
while( 1 )
{
	$frame++;
	
	### check the death file and make sure it is OK to run.
	if( -e $conf->{'dieFile'} )
	{
		properDie( "All stop found. Dying!!!" );
	}
	
	### grab all connections.
	while( 1 )
	{
		$reporter->{'log'}->( "Looking for connections |$frame|." ) if $DEBUG;
		if(my @ready = $sel->can_read( 0.001 ) )
		{
			foreach my $fh (@ready) 
			{
				my $new_sock = $fh->accept;
				if( $new_sock )
				{
					$new_sock->autoflush( 1 );
					$new_sock->blocking( 0 );
					$reporter->{'log'}->( "Accepting new connection." );
					push @pendingReads, { timeOut => 5, sock => $new_sock, pastMessage => '' };
				}
			}
		}
		else
		{
			last;
		}
	}
	
	### grab all commands
	my $index = -1;
	foreach my $clientStruct ( @pendingReads )
	{
		$index++;
		my $timeOut = $clientStruct->{"timeOut"};
		my $client = $clientStruct->{"sock"};
		my $pastMessage = $clientStruct->{"pastMessage"};
		my $recvMessage = '';
		
		if( $timeOut-- <= 0 )
        {
			$reporter->{'log'}->( "Timed out trying to get a full message from client. Only got |$pastMessage|." );
            $client->close();
			splice @pendingReads, $index, 1;
			next;
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
				$reporter->{'log'}->( "Recoverable error, try again timeLeft |$timeOut|, error was $!." );
			}
			else
			{
				$reporter->{'log'}->( "Unrecoverable error or pipe closed. End this transmission." );
				$client->close();
				splice @pendingReads, $index, 1;
				next;
			}
		}
		else
		{
			### We got something back, check to see if full message, if it is, send it out.
			$pastMessage .= $recvMessage;
			$reporter->{'log'}->( "Got more bytes from clinet, buffer is now |$pastMessage|." );
			
			if( $pastMessage =~ /(.*?)\n/ )
			{
				my $command = $1;
				Command::add( $command, $client );
				
				### remove from the reads list
				splice @pendingReads, $index, 1;
				next;
			}
		}
		
		$clientStruct->{"timeOut"} = $timeOut;
		$clientStruct->{"pastMessage"} = $pastMessage;
	}
	
	### Process all commands
	Command::runAll( \%game );
	
	### run internal periodic logic
	gamePeriodic();
	
	
	### update all player streams
	updatePlayerStreams();
	
	
	### empty the outStream since we sent it out to everyone.
	while ( @outStream > 0 )
	{
		shift @outStream;
	}
	
	
	### flush all command streams. Close connections if needed.
	Command::flushCommandStreams( );
	
	
	### print that we are alive
	if( $frame % 600 == 0 )
	{
		$reporter->{'log'}->( "---HEARTBEAT---" );
	}
	
	
	### wait so we don't eat up processor
	select(undef, undef, undef, $frameStep);
}

properDie( "Exiting OK." );

exit 0;

sub properDie
{
	my $message = shift;
	my $error = shift;
	
	$reporter->{'log'}->( $message, $error );
	
	$reporter->{'log'}->( "Closing server." );
	$server->shutdown( 2 ) if $server;
	$server->close() if $server;
	
	foreach my $commandNum ( keys %{ $command_streams } )
	{
		destroyCommand( $commandNum );
	}
	
	if( -e $conf->{'socketFile'} )
	{
		unlink $conf->{'socketFile'};
	}
	
	exit 0;
}

sub gameOver
{
	my $victor = shift;
	
	unless ( defined $players{$victor} || $victor eq "CAT")
	{
		$reporter->{'log'}->( "|$victor| is not a valid player. Game ending but nothing modified", "ERROR" );
	}
	if( $victor eq "CAT" )
	{
		$reporter->{'log'}->( "Was a CAT game." );
		$winner = "$victor";
		$players{"P1"}->{"ties"}   += 1;
		$players{"P2"}->{"ties"}   += 1;
	}
	else
	{
		$winner = "$victor";
		$players{"P1"}->{"wins"}   += ( $victor eq "P1" ) ? 1 : 0;
		$players{"P1"}->{"losses"} += ( $victor eq "P1" ) ? 0 : 1;
		$players{"P2"}->{"wins"}   += ( $victor eq "P2" ) ? 1 : 0;
		$players{"P2"}->{"losses"} += ( $victor eq "P2" ) ? 0 : 1;
		$reporter->{'log'}->( "Game ending with winner |$victor|" );
	}
	
	$gameState = "gameOver";
	$turn = 'NO_ONE';
	
	return;
}

sub updateGameInfo
{
	my $encodedOut = '';
	
	eval {
		$encodedOut = encode_json ( { 
			name     => "updateGameInfo", 
			board    => \@gameBoard, 
			status   => "$gameState",
			whosTurn => "$turn",
			winner   => "$winner",
			player   => [ 
							{ 
								name   => $players{"P1"}->{"name"}, 
								wins   => $players{"P1"}->{"wins"},
								losses => $players{"P1"}->{"losses"},
								ties   => $players{"P1"}->{"ties"},
								status => ( $players{"P1"}->{"timeout"} < 100 ) ? "good" : "timeout",
							}, 
							{
								name   => $players{"P2"}->{"name"}, 
								wins   => $players{"P2"}->{"wins"},
								losses => $players{"P2"}->{"losses"},
								ties   => $players{"P2"}->{"ties"},
								status => ( $players{"P2"}->{"timeout"} < 100 ) ? "good" : "timeout",	
							}, 
						],
		} );
	};
	if( $@ )
	{
		$reporter->{'log'}->( "Problem encoding JSON for updateGameInfo says: |$@|", "ERROR" );
		return;
	}
	
	push @outStream, $encodedOut;
	
	return;
}

sub updatePlayerStreams
{
	foreach my $player ( keys %players )
	{
		if( @{ $players{$player}->{"streams"} } > 0 )
		{
			my $currentStream = $players{$player}->{"streams"}[0];
			my $expireFrame = $currentStream->{"expireFrame"}--;
			my $commandNum  = $currentStream->{"commandNum"};
			
			unless( defined $command_streams->{"$commandNum"} )
			{
				$reporter->{'log'}->( "Stream must have closed. Get rid of it." );
				shift @{ $players{$player}->{"streams"} };
				next;
			}
			
			my $currentOutBuffer = $command_streams->{"$commandNum"}{"outBuffer"};
			$currentOutBuffer = '' unless defined $currentOutBuffer;
			
			if( $DEBUG )
			{
				my $encodedOut = encode_json ( { name => "keepAlive" } );
				$currentOutBuffer .= "$encodedOut\n";
			}
			
			foreach my $message ( @outStream )
			{
				next unless defined $message;
				$reporter->{'log'}->( "Streaming message. |$message|" );
				$currentOutBuffer .= "$message\n";
			}
			
			if( $expireFrame <= 0 )
			{
				$reporter->{'log'}->( "Stream expired closing." );
				
				$command_streams->{"$commandNum"}{"closeStream"} = 1;
				shift @{ $players{$player}->{"streams"} };
			}
			
			$command_streams->{"$commandNum"}{"outBuffer"} = $currentOutBuffer;
		}
		else
		{
			$players{$player}->{"timeout"}++;
			if( $players{$player}->{"timeout"} >= 100 && $gameState eq "gameON" )
			{
				$reporter->{'log'}->( "Player |$player| timed out, stopping active game." );
				if(    $player eq "P1" ){ GameUtil::fillBoard( \@winBoard, 'O' );  gameOver( "P2"); }
				elsif( $player eq "P2" ){ GameUtil::fillBoard( \@winBoard, 'X' );  gameOver( "P1"); }
			}
		}
	}
}

sub gamePeriodic
{
	if( $gameState eq "Waiting" )
	{
		if( $frame % 5 == 0 )
		{
			### do the waiting animation.
			GameUtil::fillBoard( \@gameBoard, '_' );
			$gameBoard[ $waitDisplayRow ]->[ $waitDisplayCol ] = $waitDisplayXO;
			
			$waitDisplayCol++;
			if( $waitDisplayCol >= 3 )
			{
				$waitDisplayCol = 0;
				$waitDisplayRow++;
				if( $waitDisplayRow >= 3 )
				{
					$waitDisplayRow = 0;
					if( $waitDisplayXO eq "X" ) {  $waitDisplayXO = "O";  }
					else						{  $waitDisplayXO = "X";  }
				}
			}
			
			updateGameInfo();
		}
	}
	elsif( $gameState eq "gameON" )
	{
		if( $frame % 10 == 0 )
		{
			### the game is a foot. Incase a player lost their stream
			### send out the data every second so they don't need to wait for a move.
			updateGameInfo();
		}
	}
	else
	{
		if( $gameState ne "gameOver" )
		{
			$reporter->{'log'}->( "State should be gameOver, but instead is |$gameState|", "ERROR" );
		}
		
		if( $frame % 10 == 0 )
		{
			GameUtil::fillBoard( \@gameBoard, '_' );
			updateGameInfo();
		}
		elsif( $frame % 5 == 0)
		{
			if( $victoryFrame < 30 )
			{
				GameUtil::copyBoard( \@gameBoard, \@winBoard);
			}
			else
			{
				if( $winner eq "CAT" )
				{
					GameUtil::fillBoard( \@gameBoard, "C" );
				}
				else
				{
					GameUtil::fillBoard( \@gameBoard, ( $winner eq "P1" ) ? "X" : "O" );
				}
			}
			updateGameInfo();
		}
		
		$victoryFrame++;
		
		if( $victoryFrame >= 50 )
		{
			$victoryFrame = 0;
			$gameState = "Waiting";
		}
	}	
}
