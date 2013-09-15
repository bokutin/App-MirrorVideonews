use utf8;
use strict;
use warnings;
use Test::More;
use Test::Data qw(Scalar);
use Test::Name::FromLine;

use IO::All;
use IO::HTML;
use xt::lib::Util;
xt::lib::Util::prepare_decrypted_files();

use_ok("App::MirrorVideonews");
use_ok("App::MirrorVideonews::Page");
my $fh = html_file("xt/data/decrypted/20130828/www.videonews.com/charged/news-commentary/index.php");
my $decoded_content = do { local $/; <$fh> };
my $app  = App::MirrorVideonews->new;
my $page = App::MirrorVideonews::Page->new( app => $app, decoded_content => $decoded_content );

my @all_blobs     = $page->all_blob_uris;
my @can_blobs     = $page->blobs;
my @hls_blobs     = $page->blobs('HLS');
my @youtube_blobs = $page->blobs('YouTube');
my @wma_blobs     = $page->blobs('WMA');
my @wmv300_blobs  = $page->blobs('WMV300');
my @wmv50_blobs   = $page->blobs('WMV50');

is @can_blobs, @hls_blobs + @youtube_blobs + @wma_blobs + @wmv300_blobs + @wmv50_blobs;
is @youtube_blobs , 7;
is $youtube_blobs[0]->save_as_basename, "ニュース・コメンタリー （2013年08月24日）8月20日、地球は赤字経営に (YouTube).flv";
is $youtube_blobs[1]->save_as_basename, "ニュース・コメンタリー （2013年08月24日）遠隔操作ウィルス事件続報弁護側が無罪性の挙証責任を負わなければならないのか (YouTube).flv";

done_testing;
