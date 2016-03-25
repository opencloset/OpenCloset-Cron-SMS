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

            my $order_rs = $DB->resultset('Order')->search( get_where( $dt_start, $dt_end ) );
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
        cron      => '55 10 * * *',
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

            my $order_rs = $DB->resultset('Order')->search( get_where( $dt_start, $dt_end ) );
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

my $worker3 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_3_day_after',
        cron      => '50 10 * * *',
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
                try { $dt_now->clone->truncate( to => 'day' )->subtract( days => 3 ); };
            return unless $dt_start;

            my $dt_end = try {
                $dt_now->clone->truncate( to => 'day' )->subtract( days => 2 )
                    ->subtract( seconds => 1 );
            };
            return unless $dt_end;

            my $order_rs = $DB->resultset('Order')->search( get_where( $dt_start, $dt_end ) );
            while ( my $order = $order_rs->next ) {
                my $ocs = OpenCloset::Cron::SMS->new(
                    order    => $order,
                    timezone => $TIMEZONE,
                );

                my $to = $order->user->user_info->phone || q{};
                my $msg = sprintf(
                    '[열린옷장] %s님, 의류 반납이 지체되고 있습니다. 추가 금액은 하루에 대여료의 20%%씩 부과됩니다. 현재 %s님의 추가 금액은 %s원입니다.',
                    $order->user->name, $order->user->name, $ocs->commify( $ocs->calc_late_fee ),
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

my $worker4 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_today_volunteer_for_guestbook',
        cron      => '00 19 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $dt_start = DateTime->now( time_zone => $TIMEZONE )->truncate( to => 'day' );
            my $dt_end = $dt_start->clone->add( days => 1 );
            my $parser = $DB->storage->datetime_parser;
            my $rs     = $DB->resultset('VolunteerWork')->search(
                {
                    status             => 'done',
                    activity_from_date => {
                        -between =>
                            [ $parser->format_datetime($dt_start), $parser->format_datetime($dt_end) ]
                    }
                }
            );

            while ( my $row = $rs->next ) {
                my $volunteer = $row->volunteer;
                ( my $to = $volunteer->phone ) =~ s/-//g;
                my $msg = sprintf(
                    '수고하셨습니다. 오늘 봉사활동 어떠셨나요? 다음 주소에 접속해 방명록을 남겨주세요. 남겨주신 방명록은 다음 봉사자 분들을 위해 활용됩니다. https://volunteer.theopencloset.net/works/%s/guestbook?authcode=%s',
                    $row->id, $row->authcode );

                my $log = sprintf( 'id(%d), volunteer_id(%d), name(%s), phone(%s), authcode(%s)',
                    $row->id, $volunteer->id, $volunteer->name, $to, $row->authcode );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        }
    );
};

my $worker5 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_today_preserved_volunteers',
        cron      => '00 08 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $dt_start = DateTime->now( time_zone => $TIMEZONE )->truncate( to => 'day' );
            my $dt_end = $dt_start->clone->add( days => 1 );
            my $parser = $DB->storage->datetime_parser;
            my $rs     = $DB->resultset('VolunteerWork')->search(
                {
                    status             => 'done',
                    activity_from_date => {
                        -between =>
                            [ $parser->format_datetime($dt_start), $parser->format_datetime($dt_end) ]
                    }
                }
            );

            while ( my $row = $rs->next ) {
                my $volunteer = $row->volunteer;
                ( my $to = $volunteer->phone ) =~ s/-//g;
                my $msg = sprintf(
                    '[열린옷장] %s님 안녕하세요 좋은 아침입니다:) 오늘은 열린옷장과 함께 봉사활동 하는 날인 것 잊지 않으셨죠? 이따 밝은 모습으로 뵙겠습니다!',
                    $volunteer->name );

                my $log = sprintf( 'id(%d), volunteer_id(%d), name(%s), phone(%s)',
                    $row->id, $volunteer->id, $volunteer->name, $to );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        }
    );
};

my $cron = OpenCloset::Cron->new(
    aelog   => $APP_CONF->{aelog},
    port    => $APP_CONF->{port},
    delay   => $APP_CONF->{delay},
    workers => [ $worker1, $worker2, $worker3, $worker4, $worker5 ],
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
    return ( $DB->storage->sql_maker->_quote_chars, $DB->storage->sql_maker->name_sep );
}

sub get_where {
    my ( $dt_start, $dt_end ) = @_;

    my ( $lquote, $rquote, $sep ) = get_quote();
    my $dtf = $DB->storage->datetime_parser;

    my $cond = {
        status_id     => 2,
        return_method => undef,
        -or           => [
            {
                # 반납 희망일이 반납 예정일보다 이른 경우 반납 예정일을 기준으로 함
                'target_date' => [
                    '-and',
                    \"> ${lquote}user_target_date${rquote}",
                    { -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ] },
                ],
            },
            {
                # 반납 희망일과 반납 예정일이 동일한 경우 반납 희망일을 기준으로 함
                'target_date'      => { -ident => 'user_target_date' },
                'user_target_date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                },
            },
            {
                # 반납 희망일이 반납 예정일보다 이후인 경우 반납 희망일을 기준으로 함
                'target_date'      => \"< ${lquote}user_target_date${rquote}",
                'user_target_date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
                },
            },
        ],
    };

    my $attr = { order_by => { -asc => 'user_target_date' } };

    return ( $cond, $attr );
}
