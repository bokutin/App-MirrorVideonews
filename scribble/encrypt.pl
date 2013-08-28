#!/usr/bin/env perl

use rlib;
use Modern::Perl;
use App::MirrorVideonews::Container qw(container);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use IO::All;

my $config = container('config')->get;
my $pass   = $config->{xt_data_crypted_key} or die "xt_data_crypted_key required.";

require Crypt::Simple;
Crypt::Simple->import( passphrase => $pass );

for my $from (io("_source/data/decrypted")->All_Files) {
    my $to = io( $from =~ s{_source/data/decrypted}{xt/data/encrypted}r || die );
    my $dir = dirname($to->pathname);
    -d $dir or make_path($dir) or die $!;
    $to->binary->print( encrypt( $from->binary->all ) );
}
