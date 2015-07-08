use strict;
use warnings;

use 5.010;

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
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "OpenCloset::Cron::SMS",
  "PREREQ_PM" => {
    "AnyEvent" => 0,
    "DateTime" => 0,
    "FindBin" => 0,
    "Getopt::Long::Descriptive" => 0,
    "Moo" => 0,
    "MooX::Types::MooseLike::Base" => 0,
    "OpenCloset::Config" => "0.002",
    "OpenCloset::Cron" => "0.002",
    "OpenCloset::Schema" => "0.012",
    "Scalar::Util" => 0,
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
  "VERSION" => "0.002",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "AnyEvent" => 0,
  "DateTime" => 0,
  "ExtUtils::MakeMaker" => "6.17",
  "File::Spec" => 0,
  "FindBin" => 0,
  "Getopt::Long::Descriptive" => 0,
  "Moo" => 0,
  "MooX::Types::MooseLike::Base" => 0,
  "OpenCloset::Config" => "0.002",
  "OpenCloset::Cron" => "0.002",
  "OpenCloset::Schema" => "0.012",
  "Scalar::Util" => 0,
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
