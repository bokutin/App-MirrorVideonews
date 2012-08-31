use Test::More;

use Modern::Perl;

#use Carp::REPL qw(nodie repl);
use Data::Dumper;
use File::Temp;
use URI;
use URI::QueryParam;

use_ok("App::videonewsdownloader::Container", "container");
use_ok("App::videonewsdownloader");

my $new_instance = sub {
    my $config = container("config");
    my $app = App::videonewsdownloader->new(
        username => $config->get->{username},
        password => $config->get->{password},
    );
};

my $app = $new_instance->();

subtest login => sub {
    ok( !$app->is_logged_in );
    ok( $app->login );
    ok(  $app->is_logged_in );

    done_testing;
};

$app = $new_instance->();

my $page_uri;

subtest pages => sub {
    my @marugeki_uris = $app->marugeki_page_uris;
    ok( @marugeki_uris );

    my @news_uris = $app->news_page_uris;
    ok( @news_uris );

    $page_uri = $marugeki_page_uris[0];

    done_testing;
};

my $mms_link;

subtest mms_links => sub {
    plan skip_all => "page not found." unless $page_uri;

    $app->mech->get($page_uri);
    my @mms_links = $app->mms_links;
    ok( @mms_links );

    $mms_link = $mms_links[0];

    done_testing;
};

subtest download_wmv => sub {
    plan skip_all => "mms link not found." unless $mms_link;

    my $tmp = File::Temp->new(SUFFIX => '.wmv');
    my $ret = $app->download_wmv( mms_uri => $mms_link, file => $tmp->filename, mock => 1 );

    ok($ret);

    done_testing;
};

done_testing;
