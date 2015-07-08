package OpenCloset::Cron::SMS;
# ABSTRACT: OpenCloset cron sms module

use utf8;
use strict;
use warnings;

our $VERSION = '0.002';

{
    package
        AnyEvent::Timer::Cron;

    use Moo;

    no warnings 'redefine';

    use AnyEvent;
    use DateTime;
    use Scalar::Util qw( weaken );

    has 'time_zone' => ( is => 'ro' );

    sub create_timer {
        my $self = shift;
        weaken $self;
        my $now = DateTime->from_epoch( epoch => AnyEvent->now );
        $now->set_time_zone( $self->time_zone ) if $self->time_zone;
        my $next = $self->next_event($now);
        return
            if not $next;
        my $interval =
            $next->subtract_datetime_absolute($now)->in_units('nanoseconds') / 1_000_000_000;
        $self->_timer(
            AnyEvent->timer(
                after => $interval,
                cb    => sub {
                    $self->{cb}->();
                    $self && $self->create_timer;
                },
            )
        );
    }

    sub next_event {
        my $self = shift;
        my $now = shift || DateTime->from_epoch( epoch => AnyEvent->now );
        $now->set_time_zone( $self->time_zone ) if $self->time_zone;
        $self->_cron->($now);
    }
}

{
    package
        OpenCloset::Cron::Worker;

    use Moo;
    use MooX::Types::MooseLike::Base qw( Str );

    no warnings 'redefine';

    use AnyEvent::Timer::Cron;
    use AnyEvent;

    has time_zone => ( is => 'ro', isa => Str );

    sub register {
        my $self = shift;

        my $name      = $self->name;
        my $cron      = $self->cron;
        my $time_zone = $self->time_zone;
        my $cb        = $self->cb;

        $cron //= q{};
        AE::log( debug => "$name: cron[$cron]" );

        if ( !$cron || $cron =~ /^\s*$/ ) {
            if ( $self->_has_timer ) {
                AE::log( info => "$name: clearing timer, cron rule is empty" );
                $self->_clear_cron;
                $self->_clear_timer;
            }
            return;
        }

        my @cron_items = split q{ }, $cron;
        unless ( @cron_items == 5 ) {
            AE::log( warn => "$name: invalid cron format" );
            return;
        }

        if ( $self->_has_timer ) {
            AE::log( debug => "$name: timer is already exists" );

            if ( $cron && $cron eq $self->_cron ) {
                return;
            }
            AE::log( info => "$name: clearing timer before register" );
            $self->_clear_cron;
            $self->_clear_timer;
        }

        AE::log( info => "$name: register [$cron]" );
        my $cron_timer = AnyEvent::Timer::Cron->new(
            cron      => $cron,
            time_zone => $time_zone,
            cb        => $cb,
        );
        $self->_cron($cron);
        $self->_timer($cron_timer);
    }
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...
