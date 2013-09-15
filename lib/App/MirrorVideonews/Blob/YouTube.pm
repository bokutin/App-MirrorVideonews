package App::MirrorVideonews::Blob::YouTube;

use Modern::Perl;
use Moose;
use namespace::autoclean;

use Data::Munge qw(trim);
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catfile);
use Guard;
use Web::Query;

with qw(App::MirrorVideonews::Role::Blob);

sub can_handle_uri {
    my ($class, $uri) = @_;

    # http://youtu.be/cJFDvvsloLA
    $uri =~ m/youtu\.be/;
}

sub download {
    my $self     = shift;
    my $filename = shift;

    my $dir      = dirname($filename);
    my $tempname = basename($filename).".temp";

    my $guard = guard { unlink catfile($dir,$tempname) };

    my @cmd = ('youtube-download', "--output", $tempname, $self->uri);
    say "cmd: " . join(" ", @cmd);

        if (my $pid = fork) {
            wait;
        }
        else {
            chdir($dir);
            exec(@cmd);
        }

    say "ret: $?";

    unless ($? == 0) {
        die $!;
    }
    $guard->cancel;
    rename $tempname, $filename or die $!;
}

sub save_as_basename {
    my $self = shift;

    my $wq = $self->page->wq;
    # href="... " とスペースが入っている場合があるため = ではなく ^= で。
    my $this = $wq->find(qq/a[href^="@{[ $self->uri ]}"]/);
    my $title1 = do {
        my $cur = $this;
        $cur = $cur->parent until $cur->find('.title1')->size;
        $cur->find('.title1')->text;
    };
    my $title2 = do {
        my $cur = $this;
        $cur = $cur->parent until $cur->find('.title2')->size;
        $cur->find('.title2')->text;
    };
    my $part = do {
        my $cur = $this;
        $cur = $cur->parent until $cur->find('tr')->size;
        $cur->text;
    };
    my $basename = join "", map { trim($_) } $title1, $title2, $part;
    my $suffix   = "flv";
    my $fullname = "$basename (YouTube).$suffix";
}

__PACKAGE__->meta->make_immutable; no Moose; 1;
