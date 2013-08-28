package App::MirrorVideonews::Container;

use Modern::Perl;
use Object::Container '-base';

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir catfile);

register "config" => sub {
    require Config::JFDI;
    my $path_to = catfile(dirname(__FILE__), "../../..");
    Config::JFDI->new( name => "mirror_videonews", path_to => $path_to, path => catdir($path_to,"etc") );
};

1;
