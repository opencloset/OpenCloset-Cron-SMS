package OpenCloset::Cron::SMS;
# ABSTRACT: OpenCloset cron sms module

use utf8;
use strict;
use warnings;

our $VERSION = '0.001';

{
    package
        AnyEvent::Timer::Cron;

    use Moo;

    no warnings 'redefine';

    use AnyEvent;
    use DateTime;
    use Scalar::Util qw( weaken );

    has 'time_zone' => (is => 'ro');

    sub create_timer {
        my $self = shift;
        weaken $self;
        my $now = DateTime->from_epoch(epoch => AnyEvent->now);
        $now->set_time_zone( $self->time_zone ) if $self->time_zone;
        my $next = $self->next_event($now);
        return
            if not $next;
        my $interval = $next->subtract_datetime_absolute($now)->in_units('nanoseconds') / 1_000_000_000;
        $self->_timer(AnyEvent->timer(
            after => $interval,
            cb => sub {
                $self->{cb}->();
                $self && $self->create_timer;
            },
        ));
    }

    sub next_event {
        my $self = shift;
        my $now = shift || DateTime->from_epoch(epoch => AnyEvent->now);
        $now->set_time_zone( $self->time_zone ) if $self->time_zone;
        $self->_cron->($now);
    }
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...
