package GameUtil;

use strict;
use warnings;

sub unTaint
{
	my $message = shift;
	
	chomp($message);
	$message =~ s/\n/\*/g;
	$message =~ s/<==/<\*\*/g;
	$message =~ s/==>/\*\*>/g;
	
	return $message;
}

sub fillBoard
{
	my $board = shift;
	my $char = shift;
	
	foreach my $row ( @{ $board } )
	{
		foreach my $col ( @{ $row } )
		{
			$col = $char;
		}
	}
}

sub copyBoard
{
	my $boardDest = shift;
	my $boardSrc  = shift;
	
	for ( my $r = 0; $r < 3; $r++ )
	{
		for ( my $c = 0; $c < 3; $c++ )
		{
			$boardDest->[$r][$c] = $boardSrc->[$r][$c];
		}
	}
}

1;
