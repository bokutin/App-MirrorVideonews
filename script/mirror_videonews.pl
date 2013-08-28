#!/usr/bin/env perl

use rlib;
use Modern::Perl;
use App::MirrorVideonews;
use App::MirrorVideonews::Container qw(container);
use Unix::PID do { __FILE__ =~ s/\.pl$/.pid/r or die };

sub run {
    local $| = 1;
    binmode STDOUT, ":utf8";

    my $config = container("config");
    my $cmd = App::MirrorVideonews->new( $config->get );
    $cmd->run;
}

run(@ARGV);
