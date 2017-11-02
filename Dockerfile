FROM opencloset/perl:latest

RUN groupadd opencloset && useradd -g opencloset opencloset

WORKDIR /tmp
COPY cpanfile cpanfile
RUN cpanm --notest \
    --mirror http://www.cpan.org \
    --mirror http://cpan.theopencloset.net \
    --installdeps .

# Everything up to cached.
WORKDIR /home/opencloset/service/OpenCloset-Cron-SMS
COPY . .
RUN chown -R opencloset:opencloset .

USER opencloset

ENV PERL5LIB "./lib:$PERL5LIB"
ENV OPENCLOSET_CRON_SMS_PORT "5000"
# Required env
# OPENCLOSET_COOLSMS_API_KEY
# OPENCLOSET_COOLSMS_API_SECRET
# OPENCLOSET_APISTORE_ID
# OPENCLOSET_APISTORE_API_STORE_KEY
# OPENCLOSET_DATABASE_DSN

CMD ["./bin/opencloset-cron-sms.pl", "./app.conf"]

EXPOSE 5000
