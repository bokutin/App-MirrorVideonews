package App::MirrorVideonews::Blob::HLS;

use Modern::Perl;
use Moose;
use namespace::autoclean;

use Data::Munge qw(trim);
use File::Which;
use List::Util qw(first);
use URI;
use URI::Find;
use YAML;

with qw(App::MirrorVideonews::Role::Blob);

sub can_handle_uri {
    my ($class, $uri) = @_;

    # Flash新: http://hlsp01.videonews.com/flash/?**********************************************
    #          -> http://hlsp01.videonews.com/637-0H/cBpX.m3u8
    # Flash旧: http://www.videonews.com/charged/flv/news_636-1r.php
    #          -> movieURL=rtmpe://fsec-videonews.bmcdn.jp/fsec-videonews/_definst_/news/news_636-1r.flv
    # iPhone:  http://hlsp01.videonews.com/637-0H/
    #          -> http://hlsp01.videonews.com/637-0H/cBpX.m3u8
    # YouTube: http://youtu.be/9gLTpZ1I_mI
    #
    # 第637回〜 Flash新
    # 〜第636回 Flash旧
    #
    # 課金チェックの為か、プレーヤーの為か、第636回までは、FlashとiPhoneでページの形式と、配信の形式が異なっていた。
    # 第637回からは、Flashページの形式が新たになり、配信の形式はiPhoneと同じものに統一されたようだ。

    return unless $uri =~ m/^http/;
    my $obj = URI->new($uri);
    return unless $obj->host =~ /hls/;
    #return unless $obj->path =~ /flash/; # Flash新のみ
    return unless $obj->path =~ m{^/\d+}; # iPhone
    return 1;
}

sub download {
    my $self = shift;
    my $filename = shift;
    (my $temp = $filename) =~ s/\.[^.]+$/.tmp$&/ or die;

    my $m3u8 = $self->_uri_to_m3u8 or die "Finding m3u8 playlist failed.";

    my $ffmpeg = which('ffmpeg') or die "ffmpeg not found.";
    my @cmd = ($ffmpeg, '-v', 'quiet', '-i', $m3u8, '-c', 'copy', $temp);
    say "cmd: " . join(" ", @cmd);
    system(@cmd);
    if ($? == 0) {
        rename $temp, $filename or die $!;
    }
    else {
        die $!;
    }
}

sub save_as_basename {
    my $self = shift;

    my $wq = $self->page->wq;
    # href="... " とスペースが入っている場合があるため = ではなく ^= で。
    my $this = $wq->find(qq/a[href^="@{[ $self->uri ]}"]/);
    my $title = do {
        my $cur = $this;
        $cur = $cur->parent until $cur->find('.title1')->size;
        $cur->find('.title1')->text;
    };
    my $part = do {
        my $cur = $this;
        $cur = $cur->parent until $cur->find('tr')->size;
        $cur->text;
    };
    my $basename = join "", map { trim($_) } $title, $part;
    my $suffix   = "flv";
    my $fullname = "$basename.$suffix";
}

# どうやらこの変換前のURIの生存期間は短かいようだ。
# 連続でダウンロードしようとすると、何回目かのダウンロードは
# この関数で http://www.videonews.com/ に戻され、失敗する。
sub _uri_to_m3u8 {
    my $self = shift;

    my $mech = $self->page->app->mech;
    my $head = $mech->get($self->uri);

    # URLの末尾のトークンキーらしきものがタイムアウトしている場合
    #   - http://hlsp01.videonews.com/633-1H -> http://hlsp01.videonews.com/633-1H/
    #     というリダイレクトはあるようだ。末尾のスラッシュに注意。
    #   - どうやら正しいトークンでアクセスしても、トップにリダイレクトされるものもあるようだ。
    #     http://hlsp01.videonews.com/622-2H/?****************************************
    #     -> http://www.videonews.com/
    #     実際にはファイルが無いか、自動のバックナンバー判定が効いているとかだと思われる。
    $mech->uri =~ /^\Q@{[$self->uri]}\E/ or App::MirrorVideonews::Exception::TokenTimeout->throw;

    my @uris;
    my $finder = URI::Find->new( sub {
        my ($uri, $orig_uri) = @_;
        push @uris, $orig_uri;
    });
    $finder->find( \$mech->res->decoded_content );

    my $m3u8 = first { /m3u8/ } @uris or die YAML::Dump( { content => $mech->res->decoded_content, uri => $self->uri, uris => \@uris } );
}

__PACKAGE__->meta->make_immutable; no Moose; 1;
