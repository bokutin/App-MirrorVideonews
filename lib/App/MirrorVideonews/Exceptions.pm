package App::MirrorVideonews::Exceptions;

use Exception::Class (
    'App::MirrorVideonews::Exception',
    'App::MirrorVideonews::Exception::NotFound'     => { isa => 'App::MirrorVideonews::Exception' },
    'App::MirrorVideonews::Exception::TokenTimeout' => { isa => 'App::MirrorVideonews::Exception' },
);

1;
