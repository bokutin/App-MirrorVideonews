package App::videonewsdownloader::Container;

use Modern::Perl;
use Object::Container '-base';

use FindBin;

register "config" => sub {
    require App::videonewsdownloader::Config;
    my $path_to = "$FindBin::Bin/..";
    App::videonewsdownloader::Config->new( name => "videonewsdownloader", path_to => $path_to, path => "$path_to/etc" );
};

1;
