package OpenCloset::Cron::SMS;
# ABSTRACT: OpenCloset cron sms module

use utf8;
use strict;
use warnings;

our $VERSION = '0.003';

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
