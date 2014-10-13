package App::MirrorVideonews;

use utf8;
use Modern::Perl;
use Moose;

use Data::Dumper;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Which;
use Guard;
use List::MoreUtils qw(uniq);
use List::Util qw(first);
use Log::Any qw($log);
use POSIX qw(strftime);
use Safe::Isa;
use Time::Duration;
use URI;
use URI::Find;
use URI::QueryParam;
use Web::Query 'wq';

has mech          => ( is => "rw", isa => "WWW::Mechanize::PhantomJS", lazy_build => 1 );
has username      => ( is => "ro", isa => "Str" );
has password      => ( is => "ro", isa => "Str" );
has save_dir      => ( is => "ro", isa => "Str" );
has archives_dirs => ( is => "ro", isa => "ArrayRef[Str]", default => sub { [] } );
has download_media_types => ( is => "ro", isa => "ArrayRef[Str]" );
has max_jobs      => ( is => "ro", isa => "Int", default => 2 );

sub exists_file {
    my $self = shift;

    my @dirs = ($self->save_dir, @{$self->archives_dirs});
    for (@dirs) {
        my $path = catfile($_, @_);
        return 1 if -f $path;
    }
}

sub is_logged_in {
    my $self = shift;

    $self->mech->get('http://www.videonews.com/');
    $self->mech->content =~ /会員情報の変更/;
}

sub login {
    my $self = shift;

    my $mech = $self->mech;

    die "Username required." unless $self->username;
    die "Password required." unless $self->password;

    $mech->get('http://www.videonews.com/');
    $mech->eval_in_page(q/ $('.loginbtn').trigger("click"); /);
    sleep 1 until $mech->content =~ /user_name/;
    $mech->submit_form(
        with_fields => {
            user_name     => $self->username,
            user_password => $self->password,
        },
    );

    my $text = $mech->content;

    if ( $text =~ m/視聴準備が完了しました/ ) {
        $log->debug("視聴準備が完了しました。");
        $mech->follow_link( url => 'http://www.videonews.com/charged/sceoscscikoine.php' );
        $log->debug("ログインしました。");
    }
    else {
        die "login failed.";
    }
}

sub run {
    my $self = shift;

    binmode STDERR, ":utf8";

    require Log::Any::Adapter;
    Log::Any::Adapter->set('Stderr');

    my $start_time = time;

    $self->login unless $self->is_logged_in;

    my @channels = $self->_channels;
    for my $channel (@channels) {
        $log->debug("--> Channel $channel");
        my @pages = $self->_pages($channel);
        for my $page (@pages) {
            $log->debug("  --> Page $page");
            my @articles = $self->_articles($page);
            for my $article (@articles) {
                $log->debug("    --> Article $article");
                my @media = $self->_media($article);
                for my $i (0..$#media) {
                    my $media = $media[$i];
                    my $type = $self->_media_type($media);
                    $log->debug("      --> Media($type) $media");
                    $self->_download($channel, $page, $article, $media, $type, $i) if grep { $_ eq $type } @{$self->download_media_types};
                }
            }
        }
    }

    # my @downloaded;
    # my @not_found;
    # my @all_blobs;
    # my @skipped;
    # my $mech = $self->mech;
    # PAGE: for my $page_uri (@page_uris) {
    #     say "==> $page_uri";
    #     $mech->get($page_uri);
    #     my @articles = $self->_articles($page_uri);
    #     for my $article (@articles) {
    #         my @m3u8 = $self->_m3u8($article);
    #     }

    #     # my $page = App::MirrorVideonews::Page->new( app => $self );
    #     # for my $type (@{$self->blob_types}) {
    #     #     for my $blob ($page->blobs($type)) {
    #     #         my $basename = $blob->save_as_basename;
    #     #         say "--> $basename";
    #     #         push @all_blobs, $blob;
    #     #         if (my $fn = $self->exists_file($basename)) {
    #     #             say "skipping. $fn";
    #     #             push @skipped, $basename;
    #     #         }
    #     #         else {
    #     #             eval { $blob->download( catfile($self->save_dir, $basename) ) };
    #     #             if (my $err = $@) {
    #     #                 if ($err->$_isa("App::MirrorVideonews::Exception::NotFound")) {
    #     #                     say "File is not found. $basename";
    #     #                     push @not_found, $basename;
    #     #                 }
    #     #                 elsif ($err->$_isa("App::MirrorVideonews::Exception::TokenTimeout")) {
    #     #                     # HLSのURIのトークンキーらしきものが、タイムアウトしている場合
    #     #                     say "The token seems to be expired. @{[ $blob->uri ]}";

    #     #                     my $num = $self->{_num_token_timeout}{$blob->uri}++;
    #     #                     my $max = 2;
    #     #                     if ($num <= $max) {
    #     #                         say "Retry($num/$max) fetching page. @{[ $page_uri ]}";
    #     #                         redo PAGE;
    #     #                     }
    #     #                     else {
    #     #                         say "Reached max retries. Skipping...";
    #     #                         push @not_found, $basename;
    #     #                     }
    #     #                 }
    #     #                 else {
    #     #                     die $err;
    #     #                 }
    #     #             }
    #     #             else {
    #     #                 push @downloaded, $basename;
    #     #             }
    #     #         }
    #     #     }
    #     # }
    # }

    # my $finish_time = time;

    # say "";
    # say "";
    # say sprintf("%d pages, %d blobs, %d skipped, %d downloaded, %d not found", 0+@page_uris, 0+@all_blobs, 0+@skipped, 0+@downloaded, 0+@not_found);
    # say "start: " . strftime("%Y-%m-%d %H:%M:%S", localtime($start_time));
    # say "finish: " . strftime("%Y-%m-%d %H:%M:%S", localtime($finish_time));
    # say "elapsed: " . duration($finish_time - $start_time);
    # say "not found: ";
    # say "\t$_" for @not_found;
    # say "succeeded.";

    exit 0;
}

sub _articles {
    my ($self, $page) = @_;

    $self->mech->get($page);

    my @uris;
    wq( $self->mech->content )->find('div.channel h2 a')->each(
        sub {
            push @uris, URI->new_abs($_->attr('href'), $page);
        }
    );

    @uris;
}

sub _channels {
    my ($self) = @_;

    my $top = 'http://www.videonews.com/channel/';

    my @href;
    $self->mech->get($top);
    wq( $self->mech->content )->find('a img')->each(
        sub {
            return unless $_->attr('alt') and $_->attr('alt') eq '一覧';
            push @href, URI->new_abs($_->parent->attr('href'), $top);
        }
    );
    @href = uniq @href;
}

sub _pids {
    my $self = shift;

    map { chomp; $_ } `pgrep -P $$`;
}

sub _download {
    my ($self, $channel, $page, $article, $media, $type, $media_idx) = @_;

    REAP: for my $pid ($self->_pids) {
        use POSIX ":sys_wait_h";
        my $kid = waitpid($pid, WNOHANG);
        if ($kid > 0) {
            my $ret = $? >> 8;
            say "pid:$pid ret:$ret";
            unless ($ret == 0) {
                kill 15, $_ for $self->_pids;
                die;
            }
        }
    }
    if ($self->_pids >= $self->max_jobs) {
        sleep 1;
        goto REAP;
    }

    my $channel_dir = (URI->new($channel)->path_segments)[1];

    if ($type eq 'FLV') {
        $self->mech->get($media);
        my @uris;
        my $finder = URI::Find->new( sub {
            my ($uri, $orig_uri) = @_;
            push @uris, $orig_uri;
        });
        $finder->find( \$self->mech->content );

        my $m3u8 = first { /m3u8/ } @uris;
        my $basename = do {
            my $uri = URI->new($m3u8);
            my $name = ($uri->path_segments)[1];
            my $ext  = "flv";
            "$name.$ext";
        };

        return if $self->exists_file($channel_dir, $basename);

        my $filename = catfile($self->save_dir, $channel_dir, $basename);
        (my $temp = $filename) =~ s/\.[^.]+$/.tmp$&/ or die;
        -d dirname($filename) or make_path dirname($filename) or die $!;

        my $ffmpeg = which('ffmpeg') or die "ffmpeg not found.";
        my @cmd = ($ffmpeg, '-v', 'quiet', '-stats', '-y', '-i', $m3u8, '-c', 'copy', $temp);
        say "cmd: " . join(" ", @cmd);

        if (my $pid = fork) {
            sleep 1;
        }
        else {
            undef &WWW::Mechanize::PhantomJS::DESTROY;
            my $ret = system(@cmd);
            if ($ret == 0) {
                rename $temp, $filename or die $!;
            }
            $log->debug("Child finish. $ret @{[ join ' ', @cmd ]}");
            exit $ret;
        }
    }
    elsif ($type eq 'WMV') {
        # http://www.videonews.com/cb/v.php?p=/marugeki/645/marugeki_645-1a.wma
        my $basename = do {
            URI->new($media)->query_param('p') =~ m{^.+/(.+)$} ? $1 : die;
        };

        return if $self->exists_file($channel_dir, $basename);

        my $filename = catfile($self->save_dir, $channel_dir, $basename);
        -d dirname($filename) or make_path dirname($filename) or die $!;

        my $mms_uri = $self->_mms_uri_by_http_uri($media);

        my $msdl    = which("msdl")   or die "msdl not found.";
        my $ffmpeg  = which("ffmpeg") or die "ffmpeg not found.";

        (my $wm1_fn = $filename) =~ s/\.[^.]+$/.unseekable$&/ or die;
        (my $wm2_fn = $filename) =~ s/\.[^.]+$/.seekable$&/   or die;
        if (my $pid = fork) {
            sleep 1;
        }
        else {
            undef &WWW::Mechanize::PhantomJS::DESTROY;
            # my $ret = system(@cmd);
            # if ($ret == 0) {
            #     rename $temp, $filename or die $!;
            # }
            # $log->debug("Child finish. $ret @{[ join ' ', @cmd ]}");
            # exit $ret;

            scope_guard {
                -f $wm1_fn and unlink $wm1_fn;
                -f $wm2_fn and unlink $wm2_fn;
            };

            {
                # 500/(300/8) = 13.33333333333333333333
                my ($in, $out, $err);
                my @cmd = ($msdl, '-s', 13, '-o', $wm1_fn, $mms_uri);
                say "cmd: " . join(" ", @cmd);
                my $ret = system(@cmd);
                say "ret: $ret";
                unless ($ret == 0) {
                    if ( -f $wm1_fn ) {
                        return;
                    }
                    else {
                        App::MirrorVideonews::Exception::NotFound->throw;
                    }
                }
            }

            {
                # http://web.archiveorange.com/archive/v/KKJCyu8LV0Kt8lTDZs1R
                # ffmpeg -i news_593-1_300r.wmv -acodec copy -vcodec copy /largefs/news_593-1_300r-copy.wmv
                my ($in, $out, $err);
                my @cmd = ($ffmpeg, '-v', 'quiet', '-stats', "-y", "-i", $wm1_fn, qw(-acodec copy -vcodec copy), $wm2_fn);
                say "cmd: " . join(" ", @cmd);
                my $ret = system(@cmd);
                say "ret: $ret";
                unless ($ret == 0) {
                    return;
                }
            }

            rename $wm2_fn, $filename or die $!;

            exit 0;
        }
    }
    elsif ($type eq 'YouTube') {
        my $basename = do {
            my $name = join "-", (URI->new($article)->path_segments)[2], $media_idx+1, "YouTube";
            my $ext  = "flv";
            "$name.$ext";
        };

        return if $self->exists_file($channel_dir, $basename);

        my $filename = catfile($self->save_dir, $channel_dir, $basename);
        (my $temp = $filename) =~ s/\.[^.]+$/.tmp$&/ or die;
        -d dirname($filename) or make_path dirname($filename) or die $!;

        my $cmd = which('youtube-dl') or die "youtube-dl not found.";
        my @cmd = ($cmd, '-o', $temp, $media);
        say "cmd: " . join(" ", @cmd);

        if (my $pid = fork) {
            sleep 1;
        }
        else {
            undef &WWW::Mechanize::PhantomJS::DESTROY;
            my $ret = system(@cmd);
            if ($ret == 0) {
                rename $temp, $filename or die $!;
            }
            $log->debug("Child finish. $ret @{[ join ' ', @cmd ]}");
            exit $ret;
        }
    }
    else {
        $log->error("Unsupported media type. $type");
    }
}

sub _media {
    my ($self, $article) = @_;

    $self->mech->get($article);
    my @uris;
    wq( $self->mech->content )->find('#player iframe')->each(
        sub {
            # <div id="player" class="backnumber_bg">
            return if $_->parent->attr('class') and $_->parent->attr('class') eq 'backnumber_bg'; # バックナンバーのYouTubeで10分程度のサンプルが落ちてくる
            push @uris, URI->new_abs($_->attr('src'), $article);
        }
    );
    wq( $self->mech->content )->find('.wmvbtn a, .audiobtn a')->each(
        sub {
            push @uris, URI->new_abs($_->attr('href'), $article);
        }
    );

    @uris;
}

sub _media_type {
    my ($self, $media) = @_;

    # http://www.videonews.com/marugeki-talk/705/
    #   http://www.videonews.com/embed/?v=U2FsdGVkX1%2FCjBTbmKPRX9%2BqlgziDaGW5ryfCs7JEhM%3D&autoplay=0&thumb=1
    #   http://www.videonews.com/embed/?v=U2FsdGVkX19P8XDM68bszUMEzEGhVWaOzieWyS8pH2w%3D&autoplay=0&thumb=1
    #   http://www.videonews.com/cb/v2.php?p=/marugeki/705/marugeki_705-1_300.wmv
    #   http://www.videonews.com/extm3/?v=U2FsdGVkX1%2BFPIYp5EyLXhSF9xPNiEuNHfiA9ycmir8%3D&t=1
    #   http://www.videonews.com/cb/v2.php?p=/marugeki/705/marugeki_705-2_300.wmv
    #   http://www.videonews.com/extm3/?v=U2FsdGVkX1%2FqUQuzEJb5XggNTSXWR9CYb%2Flgy81Vra8%3D&t=1
    #
    # http://www.videonews.com/marugeki-talk/685/
    #   http://www.youtube.com/embed/TOmlVsp7JF0?rel=0&wmode=transparent
    #   http://www.youtube.com/embed/S53MGG_DQb0?rel=0&wmode=transparent

    return 'FLV'     if $media =~ /autoplay/;
    return 'WMV'     if $media =~ /300\.wmv/;
    return 'WMA'     if $media =~ /\.wma/;
    return 'iPhone'  if $media =~ /extm3/;
    return 'YouTube' if $media =~ /youtube/;
}

sub _pages {
    my ($self, $channel) = @_;

    my $last_page = 1;

    $self->mech->get($channel);
    my $e = wq( $self->mech->content )->find('a.last')->first;
    if ($e->size) {
        $e->attr('href') =~ q{/page/(\d+)/};
        $last_page = $1 || die;
    }

    map { $channel . "page/$_/" } (1..$last_page);
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
    my ($self, $http_uri)  = @_;

    require HTML::TreeBuilder;
    my $mech = $self->mech;
    my $res  = $mech->get($http_uri);
    my $root = HTML::TreeBuilder->new;
    $root->ignore_unknown(0);
    $root->parse($mech->content);
    $root->eof;
    if ( $http_uri =~ m/\.wm/ ) {
        my $href = $root->find_by_tag_name('a')->attr('href');
        URI->new($href)->query_param('p');
    }
    else {
        $root->find_by_tag_name('ref')->attr('href');
    }
}

sub _build_mech {
    my $self = shift;
 
    require WWW::Mechanize::PhantomJS;
    my $mech = WWW::Mechanize::PhantomJS->new(
        cookie_file => 'var/cookie.dat',
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
