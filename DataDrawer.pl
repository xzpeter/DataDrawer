#!/usr/bin/perl

=head1

This is a data drawer using Gnuplot.
mailme: xzpeter@gmail.com

=cut 

use warnings;
use strict;
use Term::Menus;
use Data::Dumper;
use Term::ANSIColor;
use Chart::Gnuplot;
use Carp::Assert;
use Storable qw/dclone/;

$|++;

# split_data should like:
# $VAR1 = [
#           [
#             '128',
#             '16384',
#             'randread',
#             '0.96',
#             '0.00',
#             '142405.42',
#             '72928',
#             '2.56',
#             '0.00',
#             '0',
#             '0',
#             '1048576',
#             '0',
#             '0',
#             '21.31',
#             '0',
#             '898',
#             '14378'
#           ],
#...
# ]
our (@csv_data, @split_data, $header, @vars, @results, %vars_range, $vars_n);
# these are user selected vars/res to draw graph
our ($x1, $x2, $y1) = (0, 1, 13);
# the default fix point of vars
our (@vars_def);
# indexes of vars/results
our (%indexes);

sub usage () {
	print "
usage: __FILE__ <csv_file>

Here the csv_file should satisfy the following:

1. the first row puts the names of variables/results
2. have an empty column between variables and results.

Please check sas-15k-data.csv for example.

";
	exit (0);
}

sub array_index($$) {
	my ($arr, $thing) = @_;
	return grep {$arr->[$_] eq $thing} (0..$#{$arr});
}

sub format_number ($) {
	my $s = shift;
	my %h = (
		"b" => 1,
		"k" => 1<<10,
		"m" => 1<<20,
		"g" => 1<<30,
		"t" => 1<<40,
		"p" => 1<<50,
	);
	my $e = join "", keys %h;
	if ($s =~ /([\d.]+)([$e])/) {
		$s = $1 * $h{$2};
	}
	return $s;
}

sub parse_header () {
	our ($header, @vars, @results);
	chomp $header;
	my ($varstr, $resstr) = split /,,/, $header;
	@vars = split /,/, $varstr;
	@results = split /,/, $resstr;
	# init the %indexes hash
	my $cnt = 0;
	$indexes{$_} = $cnt++ for (@vars);
	$indexes{$_} = $cnt++ for (@results);
	$vars_n = scalar @vars;
}

# parse the file
sub parse_data () {
	our (@csv_data);
	$vars_range{$_} = [] foreach (@vars);
	my $cnt = 0;
	foreach (@csv_data) {
		chomp;
		$_ = lc $_;
		my ($varstr, $resstr) = split /,,/;
		my @v_val = split /,/, $varstr;
		my @r_val = split /,/, $resstr;
		# data line check: 
		# each line should have same vars/results with header
		$#v_val == $#vars and $#r_val == $#results
			or die "data not match with headers!";
		my $n = $#vars;
		foreach (0..$n) {
			my $val = $v_val[$_];
			my $val_list = $vars_range{$vars[$_]};
			push (@{$val_list}, $val) if not grep /^$val$/, @{$val_list};
		}
		my $entry = [@v_val, @r_val];
		$_ = format_number($_) for (@$entry);
		push @split_data, $entry;
	}
	# print Dumper \%vars_range;
}

sub set_defaults () {
	foreach (0..$#vars) {
		$vars_def[$_] = ${$vars_range{$vars[$_]}}[0];
	}
}

sub _g ($) {
	colored shift, "bold green";
}
sub _r ($) {
	colored shift, "bold red";
}
sub _u ($) {
	colored shift, "underline";
}

# load the file
usage() if scalar @ARGV != 1;
my $csv_data_file = $ARGV[0];
open my $file, "<$csv_data_file" or die "Failed open file $csv_data_file: $!";
@csv_data = <$file>;
close $file;
$header = shift @csv_data;

# parse data and header, any preparation works
parse_header();
parse_data();
set_defaults();

sub handle_set_fix_point () {
	my $title = "Which variable do you want to set?";
	my $v = pick(\@vars, $title);
	return if $v =~ /quit/i;
	print "Set default value for $v (".join(",",@{$vars_range{$v}})."): ";
	my $val = <STDIN>; chomp $val;
	foreach (0..$#vars) {
		if ($v eq $vars[$_]) {
			if (grep /$val/, @{$vars_range{$v}}) {
				$vars_def[$_] = $val;
			} else {
				print _r("Cannot set $v to this! Using previous one!\n");
				sleep 1;
			}
			last;
		}
	}
}

sub handle_set_first_var () {
	my $sel = pick (\@vars, "Which vars to choose for X1? ");
	return if $sel =~ /quit/i;
	($x1) = grep {$vars[$_] eq $sel} 0..$#vars;
}

sub handle_set_second_var () {
	my $sel = pick (\@vars, "Which vars to choose for X2? ");
	return if $sel =~ /quit/i;
	($x2) = grep {$vars[$_] eq $sel} 0..$#vars;
}

sub handle_set_first_result () {
	my $sel = pick (\@results, "Which vars to choose for Y1? ");
	return if $sel =~ /quit/i;
	($y1) = grep {$results[$_] eq $sel} 0..$#results;
}

sub not_implemented () {
	print "Not implemented currently!\n";
	sleep 1;
}

# this will create a new array with filtered data
sub filter_data (@) {
	my %goals = @_;
	return grep {
		my $ok = 1;
		for my $key (keys %goals) {
			if ($_->[$indexes{$key}] ne format_number($goals{$key})) {
				$ok = 0;
				last;
			}
		}
		$ok
	} @split_data;
}

our $output = "output.png";

sub draw_x_y ($) {
	my $data = shift;
	# Create chart object and specify the properties of the chart
	my $chart = Chart::Gnuplot->new(
		title  => $results[$y1] . " result",
		xlabel => $vars[$x1],
		ylabel => $results[$y1],
		xtics => {
			mirror => "on",
		},
		ytics => {
			mirror => "on",
		},
		x2tics => "on",
		y2tics => "on",
		grid => "on",
		output => $output,
		imagesize => "2, 2",
	);

	# Create dataset object and specify the properties of the dataset
	my $dset = Chart::Gnuplot::DataSet->new(
		points => $data,
		# title => "IOPS",
		style => "linespoints",
		width => 2,
		# color => "red",
	);

	# Plot the data set on the chart
	$chart->plot2d($dset);
	`eog $output`;
}

sub handle_draw_x_y () {
	my @requires = ();
	for (0..$#vars) {
		next if $x1 == $_;
		@requires = (@requires, $vars[$_], $vars_def[$_]);
	}
	my @data = filter_data(@requires);
	my @points = sort {$a->[0] <=> $b->[0]} map {[$_->[$x1], $_->[$vars_n+$y1]]} @data;
	draw_x_y(\@points);
}

sub assert_type ($$) {
	assert ((ref $_[0]) eq $_[1]);
}

=head3 draw_2x_y

This is a wrapper to draw 2x-y data sets. Params are:

  $title: the title of the graph
  $x_name: the name of x-axia of the graph
  $y_name: the name of y-axis
  $data_sets: should be something like this:
	{
	  "x2=a1" => [[x1,y1], [x2,y2], ...],
	  "x2=a2" => [[x1,y1], [x2,y2], ...],
	  ...
	  "x2=am" => [[x1,y1], [x2,y2], ...],
	}

=cut

sub draw_2x_y ($$$$) {
	my ($title, $x_name, $y_name, $data_sets) = @_;
	assert_type ($data_sets, "HASH");

	# Create chart object and specify the properties of the chart
	my $chart = Chart::Gnuplot->new(
		title  => $title,
		xlabel => $x_name,
		ylabel => $y_name,
		xtics => {
			mirror => "on",
		},
		ytics => {
			mirror => "on",
		},
		x2tics => "on",
		y2tics => "on",
		grid => "on",
		output => $output,
		imagesize => "2, 2",
		# legend => {
		# 	position => "top right",
		# 	width    => 20,
		# 	height   => 15,
		# 	align    => "right",
		# 	order    => "horizontal reverse",
		# 	title    => "Title of the legend",
		# 	sample   => {
		# 		length   => 50,
		# 		position => "left",
		# 		spacing  => 5,
		# 	},
		# 	border   => {
		# 		linetype => 1,
		# 		width    => 2,
		# 		color    => "black",
		# 	},
		# },
	);

	# Create dataset object and specify the properties of the dataset
	my @dsets = ();
	foreach my $case (keys %$data_sets) {
		my $dset = Chart::Gnuplot::DataSet->new(
			points => $data_sets->{$case},
			# title => "IOPS",
			style => "linespoints",
			width => 2,
			# color => "red",
		);
		push @dsets, $dset;
	}
	# Plot the data set on the chart
	$chart->plot2d(@dsets);
	`eog $output`;

}

sub handle_draw_2x_y () {
	my @requires = ();
	for (0..$#vars) {
		next if $x1 == $_ or $x2 == $_;
		@requires = (@requires, $vars[$_], $vars_def[$_]);
	}
	my @data = filter_data(@requires);
	my %data_sets;
	foreach my $line (@data) {
		my ($x1v, $x2v, $rv) = ($line->[$x1], $line->[$x2], $line->[$vars_n+$y1]);
		my $key = $vars[$x2]."=$x2v";
		$data_sets{$key} = [] if not defined $data_sets{$key};
		push @{$data_sets{$key}}, [$x1v, $rv];
	}
	foreach my $cond (keys %data_sets) {
		my @sorted = sort {$a->[0] <=> $b->[0]} @{$data_sets{$cond}};
		$data_sets{$cond} = dclone (\@sorted);
	}
	draw_2x_y($results[$y1] . " Results", $vars[$x1], $results[$y1], \%data_sets);
}

sub handle_draw_graph () {
	my @menu = (
		"X-Y graph",
		"2X-Y graph",
		"X-2Y graph",
	);
	my @handles = (
		\&handle_draw_x_y,
		\&handle_draw_2x_y,
		# \&handle_draw_x_2y,
		# \&not_implemented,
		# \&not_implemented,
		\&not_implemented,
	);
	my $sel = pick (\@menu, "What type of graph do you want to plot?");
	foreach (0..$#menu) {
		my $str = substr $menu[$_], 0, 5;
		if ($sel =~ /^$str/) {
			$handles[$_]->();
			last;
		}
	}
}

sub handle_main_menu () {
	my $title = "Please select options:";
	my @handlers = (
		\&handle_set_fix_point,
		\&handle_set_first_var,
		\&handle_set_second_var,
		\&handle_set_first_result,
		\&handle_draw_graph,
	);
	my @menu = (
		"Set variable fix point (".
			(join(",", map {_g($vars[$_])."=".$vars_def[$_]} (0..$#vars))).") ->",
		"Select first variable (as X1) ("._g($vars[$x1]).") ->",
		"Select second variable (as X2) ("._g($vars[$x2]).") ->",
		"Select first result ("._r($results[$y1]).") ->",
		"Draw graph using these params ->",
	);
	my $opt = &pick (\@menu, $title);
	foreach (0..$#menu) {
		my $str = substr $menu[$_], 0, 18;
		if ($opt =~ /^$str/) {
			$handlers[$_]->();
			last;
		}
	}
	exit if $opt =~ /quit/;
}

# this is the main loop of menu selections
while (1) {
	handle_main_menu();
}
