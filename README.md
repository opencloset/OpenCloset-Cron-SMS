# OpenCloset-Cron-SMS #

[![Build
Status](https://travis-ci.org/opencloset/OpenCloset-Cron-SMS.svg?branch=release-0.101)](https://travis-ci.org/opencloset/OpenCloset-Cron-SMS)

각종 상태별 문자메세지를 발송하는 cronjob

- 의류반납 1일 전 (11:30)
- 의류반납일 (11:40)
- 1일 연체 (11:45)
- 2일 연체 (11:35)
- 3일 연체 (14:20)
- 봉사활동 방명록 안내 (19:00)
- 봉사활동 당일 안내 (08:00)
- 배송완료된 기증신청 30일 후 (11:20)

## Build docker image ##

    $ docker build -t opencloset/cron/sms .
