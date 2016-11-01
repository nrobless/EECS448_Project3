package Command::GetGameStream;

use strict;
use warnings;

sub getGameStream
{
	my $game    = shift;
	my $command = shift;
	
	my $player     = $command->{"player"};
	my $commandNum = $command->{"commandNum"};
	
	my $reporter  = $game->{'reporter'};
	my $players   = $game->{'players'};
	
	$reporter->{'log'}->( "Setting up game stream for |$player| command |$commandNum|" );
	
	push @{ $players->{$player}{"streams"} }, { expireFrame => 50, commandNum => $commandNum };
	
	$players->{$player}{"timeout"} = 0;
	$command->{"streams"}{"$commandNum"}{"closeStream"} = 0;
}

1;
