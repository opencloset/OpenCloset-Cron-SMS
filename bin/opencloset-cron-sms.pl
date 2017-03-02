#!perl
# PODNAME:  opencloset-cron-sms.pl
# ABSTRACT: OpenCloset cron sms script

use utf8;
use strict;
use warnings;

use FindBin qw( $Script );
use Getopt::Long::Descriptive;

use Config::INI::Reader;
use Date::Holidays::KR ();
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
        name      => 'notify_1_day_before', # D-1
        cron      => '30 11 * * *',
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
                    '[열린옷장] 내일은 %d일에 대여하신 의류 반납일입니다. 내일까지 반납부탁드립니다. 택배로 반납하실 경우, 오늘까지 택배사에 접수해 주셔야 추가 비용이 발생하지 않습니다.',
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
        name      => 'notify_D_day', # D-day
        cron      => '40 11 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $today = DateTime->today( time_zone => $TIMEZONE );
            return unless $today;

            my $dt_start = $today->clone;
            return unless $dt_start;

            my $dt_end = $today->clone->add( days => 1 )->subtract( seconds => 1 );
            return unless $dt_start;

            my $order_rs = $DB->resultset('Order')->search( get_where( $dt_start, $dt_end ) );
            while ( my $order = $order_rs->next ) {
                my $user     = $order->user;
                my $to       = $user->user_info->phone || q{};
                my $order_id = $order->id;
                my $msg      = sprintf(
                    qq{[열린옷장] 오늘은 %d일에 대여하신 의류 반납일입니다. 운영시간(10시~18시) 중에는 웅진빌딩 403호로 반납해 주시고, 운영 외 시간에는 21시까지 4층 엘리베이터 앞에 무인반납함에 반납해 주세요. 대여 기간 연장이 필요하신 경우, %s 에서 대여기간을 연장해 주세요. (연장없이 무단으로 반납이 늦어지면 연체 처리 되어 하루 당 대여료의 30%%의 추가 비용이 발생합니다.) 택배로 발송하신 경우 %s 에서 택배사, 운송장번호를 등록해 주세요. (발송알리미 미입력시 택배발송 지연으로 인해 연체처리가 될 수 있습니다.)},
                    $order->rental_date->day,
                    "https://staff.theopencloset.net/order/$order_id/extension",
                    "https://staff.theopencloset.net/order/$order_id/return"
                );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $user->name, $to, $order->rental_date, $order->target_date,
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
        name      => 'notify_1_day_after', # D+1
        cron      => '45 11 * * *',
        time_zone => $TIMEZONE,
        cb        => sub {
            my $name = $w->name;
            my $cron = $w->cron;
            AE::log( info => "$name\[$cron] launched" );

            #
            # get today datetime
            #
            my $today = DateTime->today( time_zone => $TIMEZONE );
            return unless $today;

            return if is_holiday($today);

            my $dt_start = $today->clone->subtract( days => 1 );
            return unless $dt_start;

            my $dt_end = $today->clone->subtract( seconds => 1 );
            return unless $dt_end;

            my $order_rs = $DB->resultset('Order')->search( get_where( $dt_start, $dt_end ) );
            while ( my $order = $order_rs->next ) {
                my $user = $order->user;
                my $to   = $user->user_info->phone || q{};
                my $msg  = sprintf(
                    qq{[열린옷장] %s님 대여하신 의류의 반납이 1일 연체되었습니다. 대여품목 확인 후, 금일 중으로 빠른 반납 부탁드립니다.},
                    $user->name );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $user->name, $to, $order->rental_date, $order->target_date,
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
        name      => 'notify_2_day_after', # D+2
        cron      => '35 11 * * *',
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

            return if is_holiday($dt_now);

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
                my $user = $order->user;
                my $to   = $user->user_info->phone || q{};
                my $msg  = sprintf(
                    '[열린옷장] %s님 대여하신 의류의 반납이 2일 연체되었습니다. 반납이 늦어질수록 연체료 부담이 커집니다. 대여 품목 확인 후, 금일 중으로 빠른 반납 요청드립니다.',
                    $user->name );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $user->name, $to, $order->rental_date, $order->target_date,
                    $order->user_target_date );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        },
    );
};

my $worker5 = do {
    my $w;
    $w = OpenCloset::Cron::Worker->new(
        name      => 'notify_3_day_after', # D+3
        cron      => '20 14 * * *',
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

            return if is_holiday($dt_now);

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

                my $user = $order->user;
                my $to   = $user->user_info->phone || q{};
                my $msg  = sprintf(
                    '[열린옷장] %s님 대여하신 의류의 반납이 3일 연체되었습니다. 반납기한이 도래하면 대여 물품을 반환하여야 함에도 불구하고 고의로 그 반환을 거부하는 경우에는 횡령죄가 성립될 수 있습니다. 반납과 관련하여 전화연락 등 반납의사를 표현하지 않는 경우에는 반납의사가 존재하지 않는 것으로 간주되오니 대여 품목 확인 후, 금일 중으로 빠른 반납 요청드립니다.',
                    $user->name );

                my $log = sprintf(
                    'id(%d), name(%s), phone(%s), rental_date(%s), target_date(%s), user_target_date(%s)',
                    $order->id, $user->name, $to, $order->rental_date, $order->target_date,
                    $order->user_target_date );
                AE::log( info => $log );

                send_sms( $to, $msg ) if $to;
            }

            AE::log( info => "$name\[$cron] finished" );
        },
    );
};

my $worker6 = do {
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

my $worker7 = do {
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
                    status             => 'approved',
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
    workers => [ $worker1, $worker2, $worker3, $worker4, $worker5, $worker6, $worker7 ],
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
        ignore_sms    => [ undef, 0 ],
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

sub is_holiday {
    my $date = shift;
    return unless $date;

    my $year     = $date->year;
    my $month    = sprintf '%02d', $date->month;
    my $day      = sprintf '%02d', $date->day;
    my $holidays = Date::Holidays::KR::holidays($year);
    return 1 if $holidays->{ $month . $day };

    if ( my $ini = $ENV{OPENCLOSET_EXTRA_HOLIDAYS} ) {
        my $extra_holidays = Config::INI::Reader->read_file($ini);
        return $extra_holidays->{$year}{ $month . $day };
    }

    return;
}
