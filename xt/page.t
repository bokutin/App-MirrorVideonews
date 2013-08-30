use strict;
use warnings;
use Test::More;
use Test::Data qw(Scalar);
use Test::Name::FromLine;

use IO::All;
use IO::HTML;
use xt::lib::Util;
xt::lib::Util::prepare_decrypted_files();

use_ok("App::MirrorVideonews::Page");
my $fh = html_file("xt/data/decrypted/20130828/www.videonews.com/charged/on-demand/index.php");
my $decoded_content = do { local $/; <$fh> };
my $page = App::MirrorVideonews::Page->new( decoded_content => $decoded_content );

my @all_blobs    = $page->all_blob_uris;
my @can_blobs    = $page->blobs;
my @hls_blobs    = $page->blobs('HLS');
my @wma_blobs    = $page->blobs('WMA');
my @wmv300_blobs = $page->blobs('WMV300');
my @wmv50_blobs  = $page->blobs('WMV50');

is @can_blobs, @hls_blobs + @wma_blobs + @wmv300_blobs + @wmv50_blobs;
less_than @can_blobs    , @all_blobs;
less_than @wmv300_blobs , @hls_blobs;
less_than @wmv300_blobs , @wma_blobs;
is @hls_blobs           , @wma_blobs;
is @wmv300_blobs        , @wmv50_blobs;

done_testing;
