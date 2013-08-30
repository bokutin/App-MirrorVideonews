use utf8;
use strict;
use warnings;
use Test::More;
use Test::Data qw(Scalar);
use Test::Name::FromLine;

use IO::All;
use IO::HTML;
use File::Spec::Functions qw(catfile);
use xt::lib::Util;
xt::lib::Util::prepare_decrypted_files();

use_ok("App::MirrorVideonews::Blob::HLS");
use_ok("App::MirrorVideonews::Blob::WMA");
use_ok("App::MirrorVideonews::Blob::WMV300");
use_ok("App::MirrorVideonews::Blob::WMV50");
use_ok("App::MirrorVideonews::Page");

my $page = App::MirrorVideonews::Page->new(
    decoded_content => do {
        my $fh = html_file("xt/data/decrypted/20130828/www.videonews.com/charged/on-demand/index.php");
        do { local $/; <$fh> };
    }
);
my @hls = $page->blobs('HLS');
my $hls = $hls[0];
isa_ok $hls, "App::MirrorVideonews::Blob::HLS";

is $hls->save_as_basename, "第645回マル激トーク・オン・ディマンド （2013年08月24日）PART1（52分）.flv";

done_testing;
