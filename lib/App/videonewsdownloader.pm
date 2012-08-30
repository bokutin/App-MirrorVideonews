package App::videonewsdownloader;

use utf8;
use Modern::Perl;
use Moose;

use Data::Dumper;
use File::Copy;
use File::Which;
use Guard;
use HTML::TreeBuilder;
use HTTP::Request::Common;
use IPC::Run qw(run timeout);
use Params::Validate;
use URI;
use URI::QueryParam;
use WWW::Scripter;

has mech => ( is => "rw", lazy_build => 1, required => 1 );
has is_logged_in => ( is => "rw", default => 0 );

has username => ( is => "ro", required => 1 );
has password => ( is => "ro", required => 1 );

sub all_page_uris {
    my $self = shift;

    $self->require_login;

    my $mech = $self->mech;

    my $ok_max;
    my $ng_min;
    my $cur = 50;
    my $uri_for_page = sub {
        my $num = shift;
        if ($num == 1) {
            "http://www.videonews.com/charged/on-demand/index.php";
        }
        else {
            "http://www.videonews.com/charged/on-demand/index_$num.php";
        }
    };
    while (1) {
        my $res = $mech->simple_request( HEAD $uri_for_page->($cur) );
        if ($res->code == 200) {
            $ok_max = $cur;
            if ($ng_min) {
                $cur = int(($ng_min-$ok_max)/2)+$ok_max;
            }
            else {
                $cur = int($cur*2);
            }
        }
        else {
            $ng_min = $cur;
            if ($ok_max) {
                $cur = int(($ng_min-$ok_max)/2)+$ok_max;
            }
            else {
                $cur = int($cur/2);
            }
        }
        if (defined $ng_min and $ng_min==0) {
            last;
        }
        if (defined $ok_max and defined $ng_min and $ok_max+1 == $ng_min) {
            last;
        }
    }

    map { $uri_for_page->($_) } (1 .. $ok_max);
}

sub download_wmv {
    my $self = shift;
    my %p = validate(@_, { http_uri => 0, mms_uri => 0, file => 1, mock => 0 });

    my $mms_uri = $p{mms_uri} || $self->mms_uri_by_http_uri($p{http_uri}||die);
    my $msdl  = which("msdl") or die "msdl not found.";
    my $ffmpeg = which("ffmpeg") or die "ffmpeg not found.";

    if ($p{mock}) {
        # https://bitbucket.org/ebrahim/msdl/src/3587fa8345f5/teststreams.list
        $mms_uri = 'mms://011.mediaimage.jp/test/silverlight-test.wmv';
    }

    my $completed_fn = $p{file};
    die unless $completed_fn =~ m/\.wmv$/;
    my $wmv1_fn = $completed_fn =~ s/\.wmv$/.unseekable.wmv/r or die;
    my $wmv2_fn = $completed_fn =~ s/\.wmv$/.seekable.wmv/r or die;
    scope_guard {
        -f $wmv1_fn and unlink $wmv1_fn;
        -f $wmv2_fn and unlink $wmv2_fn;
    };
    
    my $test_wmv = "t/data/test.unseekable.wmv";
    if ($p{mock} and -f $test_wmv) {
        copy( $test_wmv, $wmv1_fn ) or die $!;
    } else {
        # 500/(300/8) = 13.33333333333333333333
        my @cmd = ($msdl, '-s', 13, '-o', $wmv1_fn, $mms_uri);
        system(@cmd) == 0 or die "system @cmd failed: $?";
    }

    if ($p{mock} and !-f $test_wmv) {
        copy($wmv1_fn, $test_wmv);
    }

    {
        # http://web.archiveorange.com/archive/v/KKJCyu8LV0Kt8lTDZs1R
        # ffmpeg -i news_593-1_300r.wmv -acodec copy -vcodec copy /largefs/news_593-1_300r-copy.wmv
        my ($in, $out, $err);
        my @cmd = ($ffmpeg, "-y", "-i", $wmv1_fn, qw(-acodec copy -vcodec copy), $wmv2_fn);
        run \@cmd, \$in, \$out, \$err, timeout(10*60) or die "system @cmd failed: $?";
    }

    rename $wmv2_fn, $completed_fn or die $!;

    return 1;
}

sub login {
    my $self = shift;

    my $mech = $self->mech;

    $mech->get('http://www.videonews.com/');
    $mech->follow_link( url_regex => qr/ContentsRequestReceive\.jsp\?req=2\b/ );
    $mech->submit_form(
        with_fields => {
            memberName => $self->username,
            password   => $self->password,
        },
    );
    $mech->follow_link( url_regex => qr/javascript:doSubmit/ );

    my $text = $mech->document->documentElement->as_text;

    if ( $text =~ m/現在ログイン中です/ ) {
        $self->is_logged_in(1);
    }
    else {
        die "login failed.";
    }
}

sub mms_uri_by_http_uri {
    my $self = shift;
    my $http_uri = shift;

    my $res  = $self->mech->simple_request( GET $http_uri );
    my $root = HTML::TreeBuilder->new_from_content($res->content);
    my $href = $root->find_by_tag_name('a')->attr('href');
    URI->new($href)->query_param('p');
}

sub require_login {
    my $self = shift;

    unless ( $self->is_logged_in ) {
        $self->login;
    }
}

sub wmv_links {
    my $self = shift;

    my $mech = $self->mech;

    grep { m/\.wmv$/i } map { $_->url } $mech->links;
}

sub _build_mech {
    my $self = shift;

    my $mech = WWW::Scripter->new(
        agent => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
    );
    $mech->use_plugin('JavaScript');
    $mech;
}

1;
