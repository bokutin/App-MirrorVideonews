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

my @all_blobs = $page->all_blob_uris;
my @can_blobs = $page->blobs;
my @hls_blobs = $page->blobs('HLS');
my @wma_blobs = $page->blobs('WMA');
my @wmv_blobs = $page->blobs('WMV');

is @can_blobs, @hls_blobs + @wma_blobs + @wmv_blobs;
less_than @can_blobs, @all_blobs;
less_than @wmv_blobs, @hls_blobs;
less_than @hls_blobs, @wma_blobs;
less_than @wmv_blobs, @wma_blobs;

done_testing;
