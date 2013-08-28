package App::MirrorVideonews::Role::Blob;

use Moose::Role;
use namespace::autoclean;

use MooseX::Types::URI qw(Uri);

has uri  => ( is => "ro", isa => Uri, required => 1, coerce => 1 );
has page => ( is => "ro", isa => "App::MirrorVideonews::Page", weak_ref => 1 );

requires qw(can_handle_uri download save_as_basename);

1;
