#!/usr/bin/env perl

use rlib;
use Modern::Perl;
use App::videonewsdownloader;
use App::videonewsdownloader::Container qw(container);
use Getopt::Long;
use IO::All;
use POSIX qw(strftime);
use Proc::PID::File;
use Time::Duration;

main: {
    pid: {
        my $cron = 0;
        my $result = GetOptions("cron" => \$cron);
        if ($cron) {
            my $dir = io("$FindBin::Bin/../var/run");
            $dir->mkpath or die $!;
            die "Already running!" if Proc::PID::File->running(dir => $dir);
        }
    }

    local $|=1;

    my $start_time = time;

    my $config = container("config");
    my $username = $config->get->{username};
    my $password = $config->get->{password};
    my $save_dir = $config->get->{save_dir};

    die unless $username;
    die unless $password;
    die unless -d $save_dir;

    my $www = App::videonewsdownloader->new(
        username => $username,
        password => $password,
    );
    my @page_uris = $www->all_page_uris;
    say sprintf("%d pages found.", 0+@page_uris);

    my @all_links;
    my @skipped;
    my @downloaded;

    for my $page_uri (@page_uris) {
        say $page_uri;
        my @links = $www->wmv_links( uri => $page_uri );
        @links = grep { m/300/ and m/marugeki/ } @links;
        for my $link (@links) {
            my $filename = $link =~ s{^.*/}{}r or die;
            my $file = io->catfile($save_dir, $filename);
            if ( $file->exists ) {
                say "skipping. ".$file->pathname;
                push @skipped, $file->pathname;
            }
            else {
                $www->download_wmv( http_uri => $link, file => $file->pathname ) or die;
                say "downloaded. ".$file->pathname;
                push @downloaded, $file->pathname;
            }
        }
        push @all_links, @links;
    }

    my $finish_time = time;

    say "";
    say "";
    say sprintf("%d pages, %d links, %d skipped, %d downloaded", 0+@page_uris, 0+@all_links, 0+@skipped, 0+@downloaded);
    say "start: " . strftime("%Y-%m-%d %H:%M:%S", localtime($start_time));
    say "finish: " . strftime("%Y-%m-%d %H:%M:%S", localtime($finish_time));
    say "elapsed: " . duration($finish_time - $start_time);
    say "succeeded.";

    exit 0;
}
