package App::MirrorVideonews::Container;

use strict;
use feature qw(:5.10);

use Cwd qw(abs_path);
use File::Spec::Functions qw(abs2rel catdir catfile splitdir);
use namespace::clean;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self;
}

sub import {
    my $class = shift;
    my $name  = $_[0] || 'container';
    my $pkg = caller;

    no strict 'refs';
    *{"${pkg}::${name}"} = sub {
        if (@_) {
            my $method = shift;
            $class->instance->$method(@_);
        }
        else {
            $class->instance;
        }
    };
}

sub instance {
    my $class = shift;

    no strict 'refs';
    ${"${class}::INSTANCE"} ||= $class->new;
}

################################################################################

sub app_class {
    my $self = shift;
    $self->{_app_class} //= ref($self) =~ s/::[^:]+$//r;
}

sub app_class_lc {
    my $self = shift;
    $self->{_app_class_lc} //= lc $self->app_class =~ s/::/_/gr;
}

sub app_home {
    my $self = shift;

    $self->{_app_home} //= do {
        my $file = ref($self) =~ s/::/\//gr . '.pm';
        my $path = $INC{$file} or die;
        $path =~ s/$file$//;
        my @home = splitdir $path;
        pop @home while @home && ($home[-1] =~ /^b?lib$/ || $home[-1] eq '');
        abs_path(catdir(@home) || '.');
    };
}

sub config {
    my $self = shift;

    my $local_suffix = $self->config_local_suffix;

    $self->{_config}{$local_suffix} //= do {
        my $dir = catdir($self->app_home, 'etc');
        if (-d $dir) {
            my @files = (
                catfile($dir, $self->app_class_lc.'.pl' ),
                catfile($dir, $self->app_class_lc.'_'.$local_suffix.'.pl' ),
            );

            require Config::Merged;
            Config::Merged->load_files( { files => \@files, use_ext => 1 } );
        }
        else {
            +{};
        }
    };
}


sub config_local_suffix {
    my $self = shift;

    $self->{_config_local_suffix} //= do {
        my $env_name = uc($self->app_class) . "_CONFIG_LOCAL_SUFFIX";
        $ENV{$env_name} || 'local';
    };
}

1;
