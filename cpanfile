requires "DateTime" => "0";
requires "FindBin" => "0";
requires "Getopt::Long::Descriptive" => "0";
requires "Moo" => "0";
requires "OpenCloset::Config" => "0.002";
requires "OpenCloset::Cron" => "0.003";
requires "OpenCloset::Cron::Worker" => "0";
requires "OpenCloset::Schema" => "0.012";
requires "Try::Tiny" => "0";
requires "perl" => "5.008";
requires "strict" => "0";
requires "utf8" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "Test::More" => "0";
  requires "perl" => "5.008";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
  requires "perl" => "5.008";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0";
  requires "English" => "0";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Pod::Wordlist" => "0";
  requires "Software::License::Perl_5" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
  requires "Test::Version" => "1";
  requires "perl" => "5.006";
};
