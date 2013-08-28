use strict;
use warnings;
use Test::More;
use Test::Data qw(Scalar);
use Test::Name::FromLine;

use File::Spec::Functions qw(catfile);
use IO::All;
use xt::lib::Util;
xt::lib::Util::prepare_decrypted_files();

my $psgi_app = sub {
    my ($env) = @_;
    my $saved_file = catfile("xt/data/decrypted/20130828", $env->{HTTP_HOST}, $env->{PATH_INFO});
    if (-f $saved_file) {
        [ 200, [], [ io($saved_file)->all ] ];

    }
    else {
        [ 404 ];
    }
};
use LWP::Protocol::PSGI;
LWP::Protocol::PSGI->register($psgi_app, host => 'www.videonews.com');

use_ok("App::MirrorVideonews");
my $app = App::MirrorVideonews->new( is_logged_in => 1 );
my @marugeki_page_uris = $app->marugeki_page_uris;
is @marugeki_page_uris, 66;

my @news_page_uris = $app->news_page_uris;
is @news_page_uris, 12;

done_testing;
