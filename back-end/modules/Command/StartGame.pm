package Command::StartGame;

use strict;
use warnings;

sub startGame
{
	my $game    = shift;
	my $command = shift;
	
	my $player     = $command->{"player"};
	my $commandNum = $command->{"commandNum"};
	
	my $gameState = $game->{'state'};
	my $players   = $game->{'players'};
	my $reporter  = $game->{'reporter'};
	my $prevStart = $game->{'prevStart'};
	my $gameBoard = $game->{'board'};
	my $winBoard  = $game->{'winBoard'};
	my $winner    = $game->{'winner'};
	my $turn      = $game->{'turn'};
	
	unless ( $$gameState eq "Waiting" )
	{
		$reporter->{'log'}->( "Player |$player| requested the game to start, but the game state is |$$gameState|" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	unless( ( $players->{"P1"}{"timeout"} < 100 ) && ( $players->{"P2"}{"timeout"} < 100 ) )
	{
		$reporter->{'log'}->( "Player |$player| requested the game to start, but a player is timed out." );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	### get initial previous start
	unless( defined $$prevStart )
	{
		$$prevStart = int(rand(2));
		if( $$prevStart == 0 ){ $$prevStart = "P1"; }
		else                  { $$prevStart = "P2"; }
	}
	
	### switch who goes first
	if( $$prevStart eq "P1" ){ $$turn = $$prevStart = "P2"; }
	else                     { $$turn = $$prevStart = "P1"; }
	
	GameUtil::fillBoard( $gameBoard, '_' );
	GameUtil::fillBoard( $winBoard, '_' );
	$$gameState = "gameON";
	$$winner = 'NO_ONE';
	
	$reporter->{'log'}->( "Player |$player| requested the game to start, Starting a new game." );
	$game->{'updateGameInfo'}->();
	$command->{"destroy"}->( $commandNum );
	return;
}

1;
