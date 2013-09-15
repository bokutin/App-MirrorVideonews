package App::MirrorVideonews::Page;

use Moose;
use namespace::autoclean;

use List::Flatten;
use List::Util qw(first);
use Module::Find qw(useall);
use Web::Query ();

has decoded_content => ( is => "ro", isa => "Str", lazy_build => 1 );
has app => ( is => "ro", isa => "App::MirrorVideonews", weak_ref => 1 );

has wq => ( is => "ro", isa => "Web::Query", lazy_build => 1 );

sub all_blob_uris {
    my $self = shift;

    flat $self->wq->find('a')->map( sub { $_[1]->attr('href') or () } );
}

sub blobs {
    my ($self, $type) = @_;

    my @blob_classes = useall("App::MirrorVideonews::Blob");
    @blob_classes = grep { /::$type$/ } @blob_classes if $type;

    map {
        my $uri = $_;
        my $class = first { $_->can_handle_uri($uri) } @blob_classes;
        $class ? $class->new( uri => $uri, page => $self ) : ();
    } $self->all_blob_uris;
}

sub _build_decoded_content {
    my $self = shift;

    $self->app->mech->res->decoded_content;
}

sub _build_wq {
    my $self = shift;

    Web::Query->new($self->decoded_content);
}

__PACKAGE__->meta->make_immutable; no Moose; 1;
