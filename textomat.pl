#!/usr/bin/perl
# textomat - transform text to png structure images to gain an overview
# Author: Frank Schacherer <bioinformatics@schacherer.de>
# $Date: $
# $Revision: $

=head1 SYNOPSIS

Usage: textomat.pl textfile.txt >image.png

=cut
use strict;
use warnings;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use GD;

my ($opt_h, $opt_t, $opt_s);
$opt_t = 4;
$opt_s = undef;
GetOptions(
   'h|?|help|usage' => \$opt_h,
   't|tab=i' => \$opt_t,
   's|shrink=i' => \$opt_s,
);
$opt_h and pod2usage(1);

my $TAB = 4;
my $TABHEAD = 6;
my $SPACE = 0;
my $CHAR = 1;
my $NUM = 2;
my $NEWLINE = 5;
my $OTHER = 3;

warn "TAB=$opt_t\n";
warn "determinig size...\n";
my $line;
my $maxwidth = 0;
my $linecnt = 0;

open (FH, "<$ARGV[0]") or die "$!\n";
while ($line=<FH>) {
    my $colcnt = 0;
    $line =~ s/[\r\n]+$//o;
    $linecnt++;
    print STDERR "\r$linecnt lines read" if not $linecnt % 10000;
    my @line = split //, $line;
    for my $char (@line) {
        $colcnt++;
        if ($char eq "\t") {
            my $spaces = $colcnt % $opt_t;
            $colcnt += $opt_t - $spaces - 1;
        }
    }
    $colcnt > $maxwidth and $maxwidth = $colcnt;
}
close FH;

warn "\nSize $maxwidth (width) x $linecnt (height)\n";
my $im = new GD::Image($maxwidth,$linecnt);
my %colors = (
   $SPACE => $im->colorAllocate(255,255,255),
   $CHAR => $im->colorAllocate(0,0,0),
   $OTHER => $im->colorAllocate(255,0,0),
   $NUM => $im->colorAllocate(128,128,128),
   $NEWLINE => $im->colorAllocate(255,0,255),
   $TAB => $im->colorAllocate(0,255,255),
   $TABHEAD => $im->colorAllocate(0,0,255),
   'a' => $im->colorAllocate(0,0,0),
   'c' => $im->colorAllocate(0,0,0),
   't' => $im->colorAllocate(0,0,0),
   'g' => $im->colorAllocate(0,0,0),
   'A' => $im->colorAllocate(255,255,255),
   'C' => $im->colorAllocate(255,255,255),
   'T' => $im->colorAllocate(255,255,255),
   'G' => $im->colorAllocate(255,255,255),
);

warn "processing...\n";
open (FH, "<$ARGV[0]") or die "$!\n";
$linecnt = 0;
while ($line=<FH>) {
    $linecnt++;
    print STDERR "\r$linecnt lines read" if not $linecnt % 10000;
    #$line =~ s/[\r\n]+$//o;
    my @line = split //, $line;
    my @mapline = ();
    my $colcnt = 0;
    for my $char (@line) {
        $colcnt++;
        if ($char eq "\r" or $char eq "\n") {
            push(@mapline, $NEWLINE);
        } elsif ($char eq ' ') {
            push(@mapline, $SPACE);
        } elsif ($char  eq "\t") {
            my $spaces = $colcnt % $opt_t;
            $spaces = $opt_t - $spaces;
            $colcnt += $spaces - 1;
            push(@mapline, $TABHEAD);
            for (my $i=1; $i<$spaces; $i++) {
                push(@mapline, $TAB);
            }
        } elsif ($char =~ /^[actgACTG]$/) {
            push(@mapline, $char);
        } elsif ($char =~ /^[a-zA-Z]$/) {
            push(@mapline, $CHAR);
        } elsif ($char =~ /^[0123456789.-]$/) {
            push(@mapline, $NUM);
        } else {
            push(@mapline, $OTHER);
        }
    }
    $colcnt > $maxwidth and $maxwidth = $colcnt;
    for (my $j=0; $j<$maxwidth; $j++) {
        my $color = $mapline[$j] || $SPACE;
        $im->setPixel($j,$linecnt-1,$colors{$color});
    }
}

if ($opt_s and $linecnt > $opt_s) {
    warn "shrinking to 1000 lines\n";
    my $oldim = $im;
    $im = new GD::Image($maxwidth,$opt_s);
    $im->copyResized($oldim,0,0,0,0,$maxwidth,$opt_s,$maxwidth,$linecnt);
}
binmode STDOUT;
print $im->png;

# $Log: $
