package App::MirrorVideonews::Exceptions;

package App::MirrorVideonews::Exception::NotFound;
use Moose;
with 'Throwable';
__PACKAGE__->meta->make_immutable; no Moose; 1;

package App::MirrorVideonews::Exception::TokenTimeout;
use Moose;
with 'Throwable';
__PACKAGE__->meta->make_immutable; no Moose; 1;
