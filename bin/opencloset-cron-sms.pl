#!perl
# PODNAME:  opencloset-cron-sms.pl
# ABSTRACT: OpenCloset cron sms script

use utf8;
use strict;
use warnings;

use FindBin qw( $Script );
use Getopt::Long::Descriptive;

use DateTime;
use Try::Tiny;

use OpenCloset::Config;
use OpenCloset::Cron::Worker;
use OpenCloset::Cron;
use OpenCloset::Schema;
use OpenCloset::Cron::SMS;

my $config_file = shift;
die "Usage: $Script <config path>\n" unless $config_file && -f $config_file;

my $CONF     = OpenCloset::Config::load($config_file);
my $APP_CONF = $CONF->{$Script};
my $DB_CONF  = $CONF->{database};
my $SMS_CONF = $CONF->{sms};
my $TIMEZONE = $CONF->{timezone};

die "$config_file: $Script is needed\n"    unless $APP_CONF;
die "$config_file: database is needed\n"   unless $DB_CONF;
die "$config_file: sms is needed\n"        unless $SMS_CONF;
die "$config_file: sms.driver is needed\n" unless $SMS_CONF && $SMS_CONF->{driver};
die "$config_file: timezone is needed\n"   unless $TIMEZONE;

my $DB = OpenCloset::Schema->connect(
    {
        dsn      => $DB_CONF->{dsn},
        user     => $DB_CONF->{user},
        password => $DB_CONF->{pass},
        %{ $DB_CONF->{opts} },
    }
);

my $worker1 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_1_day_before',
        cron      => '00 11 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $dt_now = try { DateTime->now( time_zone => $TIMEZONE ); };
            return unless $dt_now;

            my $dt_start = try { $dt_now->clone->truncate( to => 'day' )->add( days => 1 ); };
            return unless $dt_start;

            my $dt_end = try {
                $dt_now->clone->truncate( to => 'day' )->add( days => 2 )->subtract( seconds => 1 );
            };
            return unless $dt_end;

            my ( $lquote, $rquote, $sep ) = get_quote();

            my $dtf      = $DB->storage->datetime_parser;
            my $order_rs = $DB->resultset('Order')->search(
                {
                    status_id => 2,
                    -or       => [
                        {
                            # 반납 희망일이 반납 예정일보다 이른 경우
                            # 반납 예정일 하루 전 오전 11시에 발송
                            'target_date' => [
                                '-and',
                                \"> ${lquote}user_target_date${rquote}",
                                { -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ] },
                            ],
                        },
                        {
                            # 반납 희망일과 반납 예정일이 동일한 경우
                            # 반납 희망일 하루 전 오전 11시에 발송
                            'target_date'      => { -ident => 'user_target_date' },
                            'user_target_date' => {
                                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                            },
                        },
                        {
                            # 반납 희망일이 반납 예정일보다 이후인 경우
                            # 반납 희망일 하루 전 오전 11시에 발송
                            'target_date'      => \"< ${lquote}user_target_date${rquote}",
                            'user_target_date' => {
                                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                            },
                        },
                    ],
                },
                { order_by => { -asc => 'user_target_date' } },
            );

            while ( my $order = $order_rs->next ) {
                my $to = $order->user->user_info->phone || q{};
                my $msg = sprintf(
                    '[열린옷장] 내일은 %d일에 대여하신 의류 반납일입니다. 내일까지 반납부탁드립니다.',
                    $order->rental_date->day,
                );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $order->user->name, $to, $order->rental_date, $order->target_date,
                    $order->user_target_date );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        },
    );
};

my $worker2 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_2_day_after',
        cron      => '00 11 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $dt_now = try { DateTime->now( time_zone => $TIMEZONE ); };
            return unless $dt_now;

            my $dt_start =
                try { $dt_now->clone->truncate( to => 'day' )->subtract( days => 2 ); };
            return unless $dt_start;

            my $dt_end = try {
                $dt_now->clone->truncate( to => 'day' )->subtract( days => 1 )
                    ->subtract( seconds => 1 );
            };
            return unless $dt_end;

            my ( $lquote, $rquote, $sep ) = get_quote();

            my $dtf      = $DB->storage->datetime_parser;
            my $order_rs = $DB->resultset('Order')->search(
                {
                    status_id => 2,
                    -or       => [
                        {
                            # 반납 희망일이 반납 예정일보다 이른 경우
                            # 반납 예정일 이틀 후 오전 11시에 발송
                            'target_date' => [
                                '-and',
                                \"> ${lquote}user_target_date${rquote}",
                                { -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ] },
                            ],
                        },
                        {
                            # 반납 희망일과 반납 예정일이 동일한 경우
                            # 반납 희망일 이틀 후 오전 11시에 발송
                            'target_date'      => { -ident => 'user_target_date' },
                            'user_target_date' => {
                                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                            },
                        },
                        {
                            # 반납 희망일이 반납 예정일보다 이후인 경우
                            # 반납 희망일 이틀 후 오전 11시에 발송
                            'target_date'      => \"< ${lquote}user_target_date${rquote}",
                            'user_target_date' => {
                                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                            },
                        },
                    ],
                },
                { order_by => { -asc => 'user_target_date' } },
            );

            while ( my $order = $order_rs->next ) {
                my $to = $order->user->user_info->phone || q{};
                my $msg = sprintf(
                    '[열린옷장] %d일에 대여하신 의류가 반납되지 않았습니다. 빠른 반납 부탁드립니다.',
                    $order->rental_date->day,
                );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $order->user->name, $to, $order->rental_date, $order->target_date,
                    $order->user_target_date );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        },
    );
};

my $cron = OpenCloset::Cron->new(
    aelog   => $APP_CONF->{aelog},
    port    => $APP_CONF->{port},
    delay   => $APP_CONF->{delay},
    workers => [ $worker1, $worker2 ],
);
$cron->start;

sub send_sms {
    my ( $to, $text ) = @_;

    my $sms = $DB->resultset('SMS')->create(
        {
            from => $SMS_CONF->{ $SMS_CONF->{driver} }{_from},
            to   => $to,
            text => $text,
        }
    );
    return unless $sms;

    my %data = ( $sms->get_columns );
    return \%data;
}

sub get_quote {
    my $o_rs      = $DB->resultset('Order');
    my $rsrc      = $o_rs->result_source;
    my $sql_maker = $rsrc->storage->sql_maker;
    my ( $lquote, $rquote, $sep ) = ( $sql_maker->_quote_chars, $sql_maker->name_sep );

    return ( $lquote, $rquote, $sep );
}
