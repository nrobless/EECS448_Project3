package Command::Move;

use strict;
use warnings;

sub move
{
	my $game    = shift;
	my $command = shift;
	
	my $player         = $command->{"player"};
	my $commandNum     = $command->{"commandNum"};
	
	my $gameState = $game->{'state'};
	my $turn      = $game->{'turn'};
	my $reporter  = $game->{'reporter'};
	my $gameBoard = $game->{'board'};
	my $winBoard  = $game->{'winBoard'};
	
	unless ( ( $$gameState eq "gameON" ) && ($$turn eq $player) )
	{
		$reporter->{'log'}->( "Player |$player| tried to make a move but game state |$$gameState| and turn |$$turn|" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	unless ( ( defined $command ) && ( defined $command->{"col"} ) && ( defined $command->{"row"} ))
	{
		$reporter->{'log'}->( "Either did not get a col or row for move from player |$player|!!!", "ERROR" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	my $col = $command->{"col"};
	my $row = $command->{"row"};
	unless( ( $col =~ /\A[0-2]\Z/ )  && ( $row =~ /\A[0-2]\Z/ ) )
	{
		$reporter->{'log'}->( "Either row or col were invalid |$row| |$col| from player |$player|!!!", "ERROR" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	my $whatIsThere = $gameBoard->[ $row ][ $col ];
	unless( $whatIsThere eq "_" )
	{
		$reporter->{'log'}->( "player |$player| tried to go in a spot where there was an |$whatIsThere| |$row| |$col|!!!" );
		$command->{"destroy"}->( $commandNum );
		return;
	}
	
	my $letter = ( $player eq "P1" ) ? "X" : "O";
	$gameBoard->[ $row ][ $col ] = $letter;
	
	my $didWin = 0;
	my $isCat = 0;
	
	if(  ( $gameBoard->[ 0 ][ 0 ] eq $letter ) && ( $gameBoard->[ 0 ][ 1 ] eq $letter ) && ( $gameBoard->[ 0 ][ 2 ] eq $letter )  )
	{
		$winBoard->[0][0] = $letter; $winBoard->[0][1] = $letter; $winBoard->[0][2] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 1 ][ 0 ] eq $letter ) && ( $gameBoard->[ 1 ][ 1 ] eq $letter ) && ( $gameBoard->[ 1 ][ 2 ] eq $letter ) )
	{
		$winBoard->[1][0] = $letter; $winBoard->[1][1] = $letter; $winBoard->[1][2] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 2 ][ 0 ] eq $letter ) && ( $gameBoard->[ 2 ][ 1 ] eq $letter ) && ( $gameBoard->[ 2 ][ 2 ] eq $letter ) )
	{
		$winBoard->[2][0] = $letter; $winBoard->[2][1] = $letter; $winBoard->[2][2] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 0 ][ 0 ] eq $letter ) && ( $gameBoard->[ 1 ][ 0 ] eq $letter ) && ( $gameBoard->[ 2 ][ 0 ] eq $letter ) )
	{
		$winBoard->[0][0] = $letter; $winBoard->[1][0] = $letter; $winBoard->[2][0] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 0 ][ 1 ] eq $letter ) && ( $gameBoard->[ 1 ][ 1 ] eq $letter ) && ( $gameBoard->[ 2 ][ 1 ] eq $letter ) )
	{
		$winBoard->[0][1] = $letter; $winBoard->[1][1] = $letter; $winBoard->[2][1] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 0 ][ 2 ] eq $letter ) && ( $gameBoard->[ 1 ][ 2 ] eq $letter ) && ( $gameBoard->[ 2 ][ 2 ] eq $letter ) )
	{
		$winBoard->[0][2] = $letter; $winBoard->[1][2] = $letter; $winBoard->[2][2] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 0 ][ 0 ] eq $letter ) && ( $gameBoard->[ 1 ][ 1 ] eq $letter ) && ( $gameBoard->[ 2 ][ 2 ] eq $letter ) )
	{
		$winBoard->[0][0] = $letter; $winBoard->[1][1] = $letter; $winBoard->[2][2] = $letter;
		$didWin = 1;
	}
	elsif( ( $gameBoard->[ 0 ][ 2 ] eq $letter ) && ( $gameBoard->[ 1 ][ 1 ] eq $letter ) && ( $gameBoard->[ 2 ][ 0 ] eq $letter ) )
	{
		$winBoard->[0][2] = $letter; $winBoard->[1][1] = $letter; $winBoard->[2][0] = $letter;
		$didWin = 1;
	}
	elsif(   ( $gameBoard->[ 0 ][ 0 ] ne "_" ) && ( $gameBoard->[ 0 ][ 1 ] ne "_" ) && ( $gameBoard->[ 0 ][ 2 ] ne "_" ) 
		 &&  ( $gameBoard->[ 1 ][ 0 ] ne "_" ) && ( $gameBoard->[ 1 ][ 1 ] ne "_" ) && ( $gameBoard->[ 1 ][ 2 ] ne "_" )
		 &&  ( $gameBoard->[ 2 ][ 0 ] ne "_" ) && ( $gameBoard->[ 2 ][ 1 ] ne "_" ) && ( $gameBoard->[ 2 ][ 2 ] ne "_" )
	)
	{
		GameUtil::copyBoard( $winBoard, $gameBoard );
		$isCat = 1;
	}
	
	$reporter->{'log'}->( "Player |$player| successfully moved |$row| |$col| and |$didWin|." );
	
	if( $didWin )
	{
		$game->{'gameOver'}->( $player );
	}
	elsif( $isCat )
	{
		$game->{'gameOver'}->( "CAT" );
	}
	else
	{
		$$turn = ( $player eq "P1" ) ? "P2" : "P1";
		$reporter->{'log'}->( "It is now |$$turn|'s turn." );
	}
	
	$game->{'updateGameInfo'}->();
	$command->{"destroy"}->( $commandNum );
	return;
}

1;
