package xt::lib::Util;

use Modern::Perl;

use App::MirrorVideonews::Container qw(container);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use IO::All;

sub prepare_decrypted_files {
    my $config = container('config')->get;
    my $pass   = $config->{xt_data_crypted_key} or return;

    require Crypt::Simple;
    Crypt::Simple->import( passphrase => $pass );

    for my $from (io("xt/data/encrypted")->All_Files) {
        my $to = io( $from =~ s/encrypted/decrypted/r );
        next if $to->exists;
        my $dir = dirname($to->pathname);
        -d $dir or make_path($dir) or die $!;
        $to->binary->print( decrypt($from->binary->all) );
    }
}

1;
