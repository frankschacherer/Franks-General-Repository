#!/usr/bin/perl
# Author: Frank Schacherer <bioinformatics@schacherer.de>
# $Date: 2002/09/26 12:11:42 $
# $Revision: 1.1 $
# $Log: statlog.pl,v $
# Revision 1.1  2002/09/26 12:11:42  schacherer_f
# Generates statistics for time-entry
#
# Data structure
# %times: key => { # key filled by aggregation option, a word or a date
#       key => identical with key
#       sum => sum of durations,
#       entries => [ # list of hashes of the form
#           year,
#           month,
#           day,
#           weekday,
#           time,     # start time
#           words,    # payload
#           duration,
#           text      # printable repr.
#       ]
use strict;
use warnings;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;

my $HOURPERDAY = 24;
my $MINPERHOUR = 60;
my %MONTHS = qw(Jan 01 Feb 02 Mar 03 Apr 04 May 05 Jun 06 Jul 07 Aug 08 Sep 09 Oct 10 Nov 11 Dec 12);
my ($opt_detail, $opt_grep, $opt_frame, $opt_word, $opt_comm, $opt_rm, $opt_pos, $opt_help, $opt_day, $opt_month, $opt_year, $opt_onto, $opt_alpha, $opt_length);

GetOptions(
   't|detail' => \$opt_detail,
   'g|grep=s' => \$opt_grep,
   'f|frame=s' => \$opt_frame,
   'h|help|?' => \$opt_help,
   'd|day' => \$opt_day,
   'm|month' => \$opt_month,
   'y|year' => \$opt_year,
   'r|remove=s' => \$opt_rm,
   'w|word' => \$opt_word,
   'p|pos=s' => \$opt_pos,
   'o|onto=s' => \$opt_onto,
   'a|alphabetical' => \$opt_alpha,
   'c|comments' => \$opt_comm,
   'l|length' => \$opt_length,
);
$opt_help and pod2usage(2);

my $timetable = [];
my %times = ();
read_log();
aggregate_durations();
print_statistics();
# print Dumper($timetable);

sub read_log {
    my ($from, $lastfrom, $lastwords, $words);
    my ($date, $day, $month, $year, $weekday);
    while (my $line = <>) {
        $line =~ s/[\r\n]+$//;
        if (new_date($line)) {
            ($year, $month, $day, $weekday) = new_date($line);
            $date = "$year $month $day $weekday";
            $lastfrom = undef;
        }
        if (time_entry($line)) {
            next unless $day;
           ($from, $words) = time_entry($line);
            if (defined $lastfrom and not
                ($opt_frame and $date !~ /$opt_frame/) and not
                ($opt_grep and $lastwords !~ /$opt_grep/) and not
                ($opt_rm and $lastwords =~ /$opt_rm/)
                ) {
                my $duration = diff_time($lastfrom, $from);
                # warn "$lastfrom, $from, $duration $lastwords\n";
                my $text = "\t$date $lastfrom $lastwords ($duration')";
                push @$timetable, {
                    year => $year,
                    month => $month,
                    day => $day,
                    weekday => $weekday,
                    time => $lastfrom,
                    words => $lastwords,
                    duration => $duration,
                    text => $text};
            }
            ($lastfrom, $lastwords) = ($from, $words);
        }
    }
}
#pos and onto not implemented TODO
# in aggregating onto > pos > words > time (year > month > day)
sub aggregate_durations {
    my %keychain;
    for my $rec (@$timetable) {
        $opt_day and %keychain = ($rec->{year} . " " . $MONTHS{$rec->{month}} . " " . $rec->{day} => 1);
        $opt_month and %keychain = ($rec->{year} . " " . $MONTHS{$rec->{month}} => 1);
        $opt_year and %keychain = ($rec->{year} => 1);
        if ($opt_word) {
            %keychain = ();
            for (split / +/, $rec->{words}) {
                $keychain{$_} = 1;
            }
        }
        if ($opt_pos) {
            my @words = split / +/, $rec->{words};
            warn "@words\n";
                %keychain = ($words[$opt_pos-1] => 1);
        }
        if ($opt_onto) {
            %keychain = ();
            my @terms = split /[\s,;\|]+/, $opt_onto;
            for my $word (split / +/, $rec->{words}) {
                if (grep /$word/, @terms) {
                    $keychain{$word} = 1;
                }
            }
        }
        for my $key (keys %keychain) {
            agg_time(\%times, $key, $rec);
        }
    }
}

sub print_statistics {
    my $len = 0;
    map { $len=length($_) if length($_)>$len } keys %times;
    if ($opt_alpha) {
        for (sort {lc($a->{key}) cmp lc($b->{key})} values %times) {
            next if $opt_grep and $opt_word and $_->{key} !~ /$opt_grep/;
            print sprintf("%10s %s\n", time_string($_->{sum}), $_->{key});
            $opt_detail and print_details($_->{entries});
        }
    } else {
        for (sort {$b->{sum} <=> $a->{sum}} values %times) {
            next if $opt_grep and $opt_word and $_->{key} !~ /$opt_grep/;
            print sprintf("%10s %s\n", time_string($_->{sum}), $_->{key});
            $opt_detail and print_details($_->{entries});
        }
    }
}

sub print_details {
    my $entries = shift;
    for (@$entries) {
        print $_->{text}, "\n";
    }
}

sub new_date {
    my $line = shift;
    $line =~ /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+
        (Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
        (\d{1,2})\s(\d{4})/x and
        #warn "nd $2\n" and
        return ($4, $2, $3, $1); #year month day weekday
    return undef;
}

sub time_entry {
    my $line = shift;
    if ($opt_comm) {
        $line =~ s/,//;
    } else {
        $line =~ s/,.*//;
    }
    $line =~ /(\d{1,2}:\d{1,2})\s(\w+.*)/;
    return $1, $2;
}

sub agg_time {
    my ($aggs, $key, $rec) = @_;
    if (not defined $$aggs{$key}) {
        $$aggs{$key} = {
            key => $key,
            entries => [],
            sum => 0
            }
    }
    $$aggs{$key}{sum} += $rec->{duration};
    push @{$$aggs{$key}{entries}}, $rec;
}

sub diff_time {
    my ($from, $to) = @_;
    $from =~ /([012]?[0-9]):([0-5]?[0-9])/ or die "Not a time - $from";
    my ($fh, $fm) = ($1, $2);
    $to =~ /([012]?[0-9]):([0-5]?[0-9])/ or die "Not a time - $to";
    my ($th, $tm) = ($1, $2);
    $th < $fh and $th += $HOURPERDAY; # next day
    return $th * $MINPERHOUR + $tm - $fh * $MINPERHOUR - $fm;
}

sub time_string {
    my $time = shift;
    my $hours = int($time / $MINPERHOUR);
    my $minutes = $time % $MINPERHOUR;
    return sprintf("%3d h %02d'", $hours, $minutes);
}

__END__

=head1 NAME

statlog.pl - extracting statistics from worklog

=head1 DESCRIPTION

./statlog.pl -d -t '2003 Feb 28' worklog.txt

=head1 SYNOPSIS

statlog.pl  [options] [file(s) ...]

  Options:
    -g, --grep word    only sum up entries that match word
    -f, --frame time   only sum up entries matching timeframe
    -r, --remove word  entries keyed to word are removed (mirror to grep)

    -d, --day          aggregate per day
    -m, --month        aggregate per month
    -y, --year         aggregate per year
    -w, --word         aggregate per word
    -p, --pos          aggregate per word at position (start counting at 1)
    -o, --onto words   aggregate onto words, onto "other" if word not found in record
                       separate words by comma. allows arbitrary slicing and dicing

    -a, --alphabetical order by name (doubles as calendary)
    -l, --length       order by time spent (default)


    -h, --help         brief help message
    -c, --comments     keep comments in record lines
    -t, --detail entry list records underlying aggregation

time in format yyyy mmm dd where mmm is Jan, Feb, Mar etc.

=head1 OPTIONS

=over 4

=item B<-t entry>

Print details for entry. Use this in conjunction with day, year, month
to print details for that time frame. Details are by default ordered
in historical sequence.

=item B<-h>

Print a brief help message and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and calculate
statistics for the entries. The entries are supposed to be in the
format:

  Fri Jul  5 2002
  09:00 mail
  09:09 review-databases/companies
  13:00 sommerfest, the band played on
  18:00 quit

Lines that do not contain a time header and follow a date entry are
discarded. Characters following a comma are also discarded, unless the
-c option is set (this allows to add more detailed descriptive comments,
without genreating categories for all of the words in them)

Use the o option in conjunction with predefined lists of categories to
slice and dice the data in whichever way you like. For example,
assuming t-projects.txt contains a list of project names (all on one
line, separated by white space or commata)

statlog.pl  -o "$(cat t-projects.txt)" -t -f '2009 Dec' timelog.txt

will give you times summed up on each project, for December 09.

Note that the -f, -g and -r option evaluate as perl regexes. That
means you can list more than one word by separating them by pipes
(along other, horrible things...)

statlog.pl -a -m -r 'lunch|admin' timelog.txt

Will not count administration or lunch times while tallying the work
time for each month.


=head1 AUTHOR

Frank Schacherer <bioinformatics@schacherer.de>

=head1 VERSION

$Date: 2002/09/26 12:11:42 $
$Revision: 1.1 $

=cut

