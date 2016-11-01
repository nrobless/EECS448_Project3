#!/usr/bin/perl

use strict;
use warnings;

use lib "/home/jfustos/perl5/share/perl5";
use lib "/home/jfustos/perl5/lib64/perl5";
use lib "/home/jfustos/perl5/lib/perl5";
use CGI;

my $cgi = CGI->new;
print $cgi->header(
	-type               => 'application/json',
);

system "nohup /home/jfustos/EECS448/ticTacToe/gameLobby.pl &>/home/jfustos/EECS448/ticTacToe/gameFiles/deathOut &";

print "game probably started\n";

exit 0;
