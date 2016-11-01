package Command::SendMessage;

use strict;
use warnings;

use JSON;

sub sendMessage
{
	my $game    = shift;
	my $command = shift;
	
	my $player     = $command->{"player"};
	my $commandNum = $command->{"commandNum"};
	
	my $reporter   = $game->{'reporter'};
	my $outStream  = $game->{'outStream'};
	
	unless ( ( defined $command ) && ( defined $command->{"message"} ) )
	{
		$reporter->{'log'}->( "Did not get a message for sendMessage!!!", "ERROR" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	my $message = $command->{"message"};
	$message = GameUtil::unTaint($message);
	
	$reporter->{'log'}->( "Sending out from player |$player| the message |$message|" );
	
	my $encodedOut;
	eval {
		$encodedOut = encode_json ( { name => "newMessage", player => $player, message => $message } );
	};
	if( $@ )
	{
		$reporter->{'log'}->( "Problem encoding JSON for sendMessage says: |$@|", "ERROR" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	push @{ $outStream }, $encodedOut;
	
	$command->{"destroy"}->( $commandNum );
	return;
}

1;
