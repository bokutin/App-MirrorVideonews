#!/usr/bin/env perl

use rlib;
use Modern::Perl;
use App::videonewsdownloader;
use App::videonewsdownloader::Container qw(container);
use Getopt::Long;
use IO::All;
use List::Util qw(first);
use POSIX qw(strftime);
use Proc::PID::File;
use Time::Duration;

main: {
    my $start_time = time;

    my $config        = container("config");
    my $username      = $config->get->{username};
    my $password      = $config->get->{password};
    my $save_dir      = $config->get->{save_dir};
    my $archives_dirs = $config->get->{archives_dirs} || [];

    my $is_movie_exists = sub {
        my $file = shift;

        first { -f } map { File::Spec->catfile($_, $file) } ($save_dir, @$archives_dirs);
    };

    pid: {
        my $cron = 0;
        my $result = GetOptions(
            "cron"       => \$cron,
            "username=s" => \$username,
            "password=s" => \$password,
            "save_dir=s" => \$save_dir,
        );
        if ($cron) {
            my $dir = io("$FindBin::Bin/../var/run");
            $dir->mkpath or die $!;
            die "Already running!" if Proc::PID::File->running(dir => $dir);
        }
    }

    die "username required." unless $username;
    die "password required." unless $password;
    die "save_dir required." unless -d $save_dir;

    local $|=1;

    my $app = App::videonewsdownloader->new(
        username => $username,
        password => $password,
    );
    my @marugeki_uris = $app->marugeki_page_uris;
    my @news_uris     = $app->news_page_uris;
    my @page_uris     = (@marugeki_uris, @news_uris);
    say sprintf("%d pages found. (marugeki: %d, news: %d)", 0+@page_uris, 0+@marugeki_uris, 0+@news_uris);

    my @all_links;
    my @skipped;
    my @downloaded;
    my @not_found;

    for my $page_uri (@page_uris) {
        say $page_uri;
        my $res = $app->mech->get($page_uri);
        unless ( $res->code == 200 ) {
            die $res->code . ": " . $page_uri;
        }
        my @links = $app->http_links;
        @links = grep { !m/50r?\./ } @links; # 50Kbps版はスキップ
        for my $http_uri (@links) {
            my $mms_uri = $app->mms_uri_by_http_uri($http_uri);
            my $filename = (URI->new($mms_uri)->path_segments)[-1];
            next if $filename =~ m/\.wma/;
            if ( my $pathname = $is_movie_exists->($filename) ) {
                say "skipping. ".$pathname;
                push @skipped, $pathname;
            }
            else {
                my $file = io->catfile($save_dir, $filename);

                # mms_uriを渡さず、http_uriを渡す。
                # mms_uriのkeyの期限が切れている場合があるため、ダウンロードの前に取得し直す。
                my $code = $app->download_wmv( http_uri => $http_uri, file => $file->pathname ) or die;
                if ($code == 200) {
                    say "downloaded. ".$file->pathname;
                    push @downloaded, $file->pathname;
                }
                elsif ($code == 404) {
                    say "not found. ".$file->pathname;
                    push @not_found, $file->pathname;
                }
                else {
                    die;
                }
            }
        }
        push @all_links, @links;
    }

    my $finish_time = time;

    say "";
    say "";
    say sprintf("%d pages, %d links, %d skipped, %d downloaded, %d not found", 0+@page_uris, 0+@all_links, 0+@skipped, 0+@downloaded, 0+@not_found);
    say "start: " . strftime("%Y-%m-%d %H:%M:%S", localtime($start_time));
    say "finish: " . strftime("%Y-%m-%d %H:%M:%S", localtime($finish_time));
    say "elapsed: " . duration($finish_time - $start_time);
    say "not found: ";
    say "\t$_" for @not_found;
    say "succeeded.";

    exit 0;
}
