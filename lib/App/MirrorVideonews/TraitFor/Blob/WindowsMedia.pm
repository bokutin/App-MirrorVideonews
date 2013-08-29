package App::MirrorVideonews::TraitFor::Blob::WindowsMedia;

use Modern::Perl;
use Moose::Role;

use File::Copy;
use File::Which;
use Guard;
use HTML::TreeBuilder;
use HTTP::Request::Common qw(GET);
use URI;
use URI::QueryParam;

our $MOCK = 0;

sub download {
    my $self = shift;
    my $filename = shift;

    my $mms_uri = $self->_mms_uri_by_http_uri($self->uri);
    my $msdl    = which("msdl")   or die "msdl not found.";
    my $ffmpeg  = which("ffmpeg") or die "ffmpeg not found.";

    (my $wm1_fn = $filename) =~ s/\.[^.]+$/.unseekable$&/ or die;
    (my $wm2_fn = $filename) =~ s/\.[^.]+$/.seekable$&/   or die;
    scope_guard {
        -f $wm1_fn and unlink $wm1_fn;
        -f $wm2_fn and unlink $wm2_fn;
    };

    my $test_wmv = "t/data/test.unseekable.wmv";
    if ($MOCK and -f $test_wmv) {
        copy( $test_wmv, $wm1_fn ) or die $!;
    }
    else {
        # 500/(300/8) = 13.33333333333333333333
        my ($in, $out, $err);
        my @cmd = ($msdl, '-s', 13, '-o', $wm1_fn, $mms_uri);
        say "cmd: " . join(" ", @cmd);
        system(@cmd);
        say "ret: $?";
        unless ($? == 0) {
            if ( -f $wm1_fn ) {
                return;
            }
            else {
                App::MirrorVideonews::Exception::NotFound->throw;
            }
        }
    }

    if ($MOCK and !-f $test_wmv) {
        copy($wm1_fn, $test_wmv);
    }

    {
        # http://web.archiveorange.com/archive/v/KKJCyu8LV0Kt8lTDZs1R
        # ffmpeg -i news_593-1_300r.wmv -acodec copy -vcodec copy /largefs/news_593-1_300r-copy.wmv
        my ($in, $out, $err);
        my @cmd = ($ffmpeg, "-y", "-i", $wm1_fn, qw(-acodec copy -vcodec copy), $wm2_fn);
        say "cmd: " . join(" ", @cmd);
        system(@cmd);
        say "ret: $?";
        unless ($? == 0) {
            return;
        }
    }

    rename $wm2_fn, $filename or die $!;
}

sub save_as_basename {
    my $self = shift;

    # http://www.videonews.com/cb/v.php?p=/marugeki/645/marugeki_645-1a.wma
    URI->new($self->uri)->query_param('p') =~ m{^.+/(.+)$} ? $1 : die;
}

# mms://wm-videonews.bmcdn.jp/wm-videonews/news/news_573-0_300.wmv?key=....
# http_uriから得られるmms_uriはkeyが付く。
# このkeyの有効期間は長くはないよう。
# http_uri -> mms_uri -> mmsダウンロード は続けて行なったほうが無難っぽい。
#
# 有料のwmvは、key付き。
#   http://www.videonews.com/cb/v.php?p=/marugeki/591/marugeki_591-1_300.wmv
#       -> mms://wm-videonews.bmcdn.jp/wm-videonews/news/marugeki_591-1_300.wmv?key=....
# 無料のwmvは、asxで、key無し。
#   http://www.videonews.com/asx/news/news_591-1.asx
#       -> mms://wm1-videonews.bmcdn.jp/wm1-videonews/news/news_591-1_300.wmv
sub _mms_uri_by_http_uri {
    my $self = shift;
    my $http_uri = shift;

    my $mech = $self->page->app->mech;
    my $res  = $mech->simple_request( GET $http_uri );
    my $root = HTML::TreeBuilder->new;
    $root->ignore_unknown(0);
    $root->parse($res->content);
    $root->eof;
    if ( $http_uri =~ m/\.wm/ ) {
        my $href = $root->find_by_tag_name('a')->attr('href');
        URI->new($href)->query_param('p');
    }
    else {
        $root->find_by_tag_name('ref')->attr('href');
    }
}

1;
