package Conf;

use strict;
use warnings;

my %conf = (
	logFile		=> "/home/jfustos/EECS448/ticTacToe/log.txt",
	socketFile  => "/home/jfustos/EECS448/ticTacToe/gameFiles/1234567890",
	dieFile	 	=> "/home/jfustos/EECS448/ticTacToe/gameFiles/die",
);

sub get
{
	return \%conf;
}

1;
