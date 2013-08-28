package App::MirrorVideonews::Blob::WMA;

use Moose;
use namespace::autoclean;

with qw(App::MirrorVideonews::Role::Blob App::MirrorVideonews::TraitFor::Blob::WindowsMedia);

sub can_handle_uri {
    my ($class, $uri) = @_;

    $uri =~ m/\.wma$/i;
}

__PACKAGE__->meta->make_immutable; no Moose; 1;
