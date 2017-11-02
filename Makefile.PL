use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.17;

my %WriteMakefileArgs = (
  "ABSTRACT" => "OpenCloset cron sms module",
  "AUTHOR" => "\x{ae40}\x{b3c4}\x{d615} - Keedi Kim <keedi\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "OpenCloset-Cron-SMS",
  "EXE_FILES" => [
    "bin/opencloset-cron-sms.pl"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "OpenCloset::Cron::SMS",
  "PREREQ_PM" => {
    "Config::INI::Reader" => 0,
    "Date::Holidays::KR" => 0,
    "DateTime" => 0,
    "FindBin" => 0,
    "Getopt::Long::Descriptive" => 0,
    "Moo" => 0,
    "OpenCloset::Config" => "0.002",
    "OpenCloset::Cron" => "0.003",
    "OpenCloset::Cron::Worker" => 0,
    "OpenCloset::Schema" => "0.012",
    "Try::Tiny" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.101",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Config::INI::Reader" => 0,
  "Date::Holidays::KR" => 0,
  "DateTime" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "FindBin" => 0,
  "Getopt::Long::Descriptive" => 0,
  "Moo" => 0,
  "OpenCloset::Config" => "0.002",
  "OpenCloset::Cron" => "0.003",
  "OpenCloset::Cron::Worker" => 0,
  "OpenCloset::Schema" => "0.012",
  "Test::More" => 0,
  "Try::Tiny" => 0,
  "strict" => 0,
  "utf8" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
