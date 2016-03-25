package OpenCloset::Cron::SMS;
# ABSTRACT: OpenCloset cron sms module

use utf8;
use Moo;

our $VERSION = '0.008';

use DateTime;

has order    => ( is => 'ro', required => 1 );
has timezone => ( is => 'ro', required => 1 );

sub _order_clothes_price {
    my $self = shift;

    return 0 unless $self->order;

    my $price = 0;
    for ( $self->order->order_details ) {
        next unless $_->clothes;
        $price += $_->price;
    }

    return $price;
}

sub _calc_overdue {
    my $self = shift;

    return 0 unless $self->order;

    my $target_dt = $self->order->target_date;
    my $return_dt = $self->order->return_date;

    return 0 unless $target_dt;

    $return_dt ||= DateTime->now( time_zone => $self->timezone );

    my $DAY_AS_SECONDS = 60 * 60 * 24;

    my $epoch1 = $target_dt->epoch;
    my $epoch2 = $return_dt->epoch;

    my $dur = $epoch2 - $epoch1;
    return 0 if $dur < 0;
    return int( $dur / $DAY_AS_SECONDS ) + 1;
}

sub commify {
    my $self = shift;
    local $_ = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
}

sub calc_late_fee {
    my $self = shift;

    my $price   = $self->_order_clothes_price( $self->order );
    my $overdue = $self->_calc_overdue( $self->order );
    return 0 unless $overdue;

    my $late_fee = $price * 0.2 * $overdue;

    return $late_fee;
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    $ #
    $ # config file is needed
    $ #
    $ cat /path/to/app.conf
    ...
    {
        ...
        timezone => 'Asia/Seoul',

        database => {
            dsn    => $ENV{OPENCLOSET_DATABASE_DSN}  || "dbi:mysql:opencloset:127.0.0.1",
            name   => $ENV{OPENCLOSET_DATABASE_NAME} || 'opencloset',
            user   => $ENV{OPENCLOSET_DATABASE_USER} || 'opencloset',
            pass   => $ENV{OPENCLOSET_DATABASE_PASS} // 'opencloset',
            opts   => $db_opts,
        },

        sms => {
            driver        => 'KR::APIStore',
            'KR::CoolSMS' => {
                _api_key    => $ENV{OPENCLOSET_COOLSMS_API_KEY}    || q{},
                _api_secret => $ENV{OPENCLOSET_COOLSMS_API_SECRET} || q{},
                _from       => $SMS_FROM,
            },
            'KR::APIStore' => {
                _id            => $ENV{OPENCLOSET_APISTORE_ID}            || q{},
                _api_store_key => $ENV{OPENCLOSET_APISTORE_API_STORE_KEY} || q{},
                _from          => $SMS_FROM,
            },
        },

        'opencloset-cron-sms.pl' => {
            port  => 8004,
            delay => 10,
            aelog => 'filter=debug:log=stderr',
        },
    };

    $ #
    $ # launch the script
    $ #
    $ opencloset-cron-sms.pl /path/to/app.conf


=head1 DESCRIPTION

...


=attr order

=attr timezone

=method commify

=method calc_late_fee
