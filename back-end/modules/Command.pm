package Command;

use strict;
use warnings;

use JSON;
use POSIX;

require "modules/Command/GetGameStream.pm";
require "modules/Command/SendMessage.pm";
require "modules/Command/StartGame.pm";
require "modules/Command/Move.pm";

my @command_que = ();
my %command_streams = ();
my $COMMANDNUM = 1;
my $reporter;

my %valid_commands = (
	getGameStream => \&Command::GetGameStream::getGameStream,
	sendMessage   => \&Command::SendMessage::sendMessage,
	startGame     => \&Command::StartGame::startGame,
	move          => \&Command::Move::move,
);

sub setReporter{ $reporter = shift; }
sub getCommandStreams{ return \%command_streams; }

sub add
{
	my $command = shift;
	my $client  = shift;
	my $commandNum = takeNum();
	
	$reporter->{'log'}->( "Got complete commmand from client, was |$command| num |$commandNum|." );
	
	### add the command to the queue and set up an output stream for it.
	push @command_que, { num => $commandNum, command => $command };
	$command_streams{"$commandNum"} = { sock => $client, outBuffer => '', closeStream => 1, timeOut => 5 };
}

sub runAll
{
	my $game = shift;
	
	while ( my $command = shift @command_que)
	{
		runCommand( $command, $game );
	}
}

sub runCommand
{
	my $command_struct = shift;
	my $game = shift;

	my $command;
	my $encodedCommand = $command_struct->{"command"};
	my $commandNum     = $command_struct->{"num"};
	
	my $players   = $game->{'players'};
	
	eval{   $command = decode_json( $encodedCommand );    };
	if ( $@ )
	{
		$reporter->{'log'}->( "Problem decoding JSON string: |$encodedCommand|. says:\n$@", "ERROR" );
		destroyCommand( $commandNum );
		return;
	}
	
	unless ( ( defined $command ) && ( defined $command->{"name"} ) )
	{
		$reporter->{'log'}->( "Request did not have a |name| field. Request was: |$encodedCommand|", "ERROR" );
		destroyCommand( $commandNum );
		return;
	}
	
	my $command_name = $command->{"name"};
	unless ( defined $valid_commands{ $command_name } )
	{
		$reporter->{'log'}->( "The name of the request was not valid. Request was: |$encodedCommand|", "ERROR" );
		destroyCommand( $commandNum );
		return;
	}
	
	unless ( ( defined $command ) && ( defined $command->{"player"} ) )
	{
		$reporter->{'log'}->( "Request did not have a |player| field. Request was: |$encodedCommand|", "ERROR" );
		destroyCommand( $commandNum );
		return;
	}
	
	my $player_name = $command->{"player"};
	unless ( defined $players->{ $player_name } )
	{
		$reporter->{'log'}->( "The name of the player was not valid. Request was: |$encodedCommand|", "ERROR" );
		destroyCommand( $commandNum );
		return;
	}
	
	$command->{"commandNum"} = $commandNum;
	$command->{"destroy"} = \&destroyCommand;
	$command->{"streams"} = \%command_streams;
	
	$valid_commands{ $command_name }->( $game, $command );
}

sub takeNum
{
	return $COMMANDNUM++;
}

sub destroyCommand
{
	my $commandNum = shift;
	
	$command_streams{"$commandNum"}->{"sock"}->close();
	delete $command_streams{"$commandNum"};
}

sub flushCommandStreams
{
	my $game  = shift;
	my $DEBUG = $game->{'DEBUG'};
	
	foreach my $commandNum ( keys %command_streams )
	{
		my $client      = $command_streams{"$commandNum"}->{"sock"};
		my $outBuffer   = $command_streams{"$commandNum"}->{"outBuffer"};
		my $closeStream = $command_streams{"$commandNum"}->{"closeStream"};
		my $timeOut     = $command_streams{"$commandNum"}->{"timeOut"};
		
		unless( defined $outBuffer )
		{
			$command_streams{"$commandNum"}->{"outBuffer"} = '';
			$outBuffer = '';
		}
		
		if( $timeOut-- <= 0 )
		{
			$reporter->{'log'}->( "Timed out trying to send |$outBuffer|. Was not completely sent. Dieing." );
			destroyCommand( $commandNum );
			next;
		}
		
		if( ( length $outBuffer )  ==  0 )
		{
			$reporter->{'log'}->( "No characters in buffer for command |$commandNum|." ) if $DEBUG;
			if( $closeStream )
			{	
				destroyCommand( $commandNum );
				$reporter->{'log'}->( "Destroying |$commandNum|." );
			}
			
			next;
		}
		
		my $byteSent = $client->send( $outBuffer, 0 );
		
		unless( ( defined $byteSent ) && ( $byteSent > 0 ) )
		{
			if( !(defined $byteSent) && (
					( $! == POSIX::EAGAIN ) || ( $! == POSIX::EWOULDBLOCK ) || ( $! == POSIX::EINTR )
				)
			)
			{
				$reporter->{'log'}->( "Trying to send |$outBuffer| again, error was $!." );
			}
			else
			{
				$reporter->{'log'}->( "Unrecoverable error or pipe closed trying to send |$outBuffer|." );
				destroyCommand( $commandNum );
				next;
			}
		}
		else
		{
			if( $byteSent >= length $outBuffer )
			{
				$reporter->{'log'}->( "Successfully sent |$outBuffer|. Message complete." );
				
				if( $closeStream )
				{
					destroyCommand( $commandNum );
					$reporter->{'log'}->( "Destroying |$commandNum|." );
					next;
				}
				
				$outBuffer = '';
			}
			else
			{
				$outBuffer = substr $outBuffer, $byteSent;
				$reporter->{'log'}->( "Successfully sent |$byteSent| bytes trying to send rest |$outBuffer|." );
			}
			
			$timeOut = 5;
		}
		
		$command_streams{"$commandNum"}->{"timeOut"} = $timeOut;
		$command_streams{"$commandNum"}->{"outBuffer"} = $outBuffer;
	}
}

1;
