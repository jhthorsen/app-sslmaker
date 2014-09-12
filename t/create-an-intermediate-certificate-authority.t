use strict;
use Test::More;
use App::sslmaker;

# https://jamielinux.com/articles/2013/08/create-an-intermediate-certificate-authority/

plan skip_all => 'linux is required' unless $^O eq 'linux';

my $asset;
my $intermediate_home = Path::Tiny->new('local/tmp/step-2-intermediate/intermediate');
my $ca_home = Path::Tiny->new('local/tmp/step-2-intermediate/ca');
my $ca_args = {
  bits => 1024, # really bad bits
  cert => $ca_home->child('certs/ca.cert.pem'),
  days => 20,
  home => $ca_home,
  key => $ca_home->child('private/ca.key.pem'),
  passphrase => $ca_home->child('private/passphrase'),
  subject => '/CN=whatever.example.com',
};

# clean up old run
$ca_home->remove_tree({ safe => 0 }) if -d $ca_home;
$intermediate_home->remove_tree({ safe => 0 }) if -d $intermediate_home;

{
  diag 'tested in t/act-as-your-own-certificate-authority.t';
  my $sslmaker = App::sslmaker->new;
  $sslmaker->make_directories({ home => $ca_home, templates => 1 });
  $sslmaker->with_config(make_key => $ca_args);
  ok -e $ca_args->{key}, 'ca key created';
  $sslmaker->with_config(make_cert => $ca_args);
  ok -e $ca_args->{cert}, 'ca cert created';
}

{
  diag 'make intermediate';
  my $sslmaker = App::sslmaker->new;
  my $intermediate_args = {
    bits => 1024, # really bad bits
    csr => $intermediate_home->child('certs/intermediate.csr.pem'),
    days => 20,
    home => $intermediate_home,
    key => $intermediate_home->child('private/intermediate.key.pem'),
    passphrase => $ca_home->child('private/passphrase'),
    subject => '/CN=test.example.com',
  };

  $sslmaker->make_directories({ home => $intermediate_home, templates => 1 });

  $sslmaker->with_config(make_key => $intermediate_args);
  ok -e $intermediate_args->{key}, 'intermediate key created';
  is +(stat $intermediate_args->{key})[2] & 0777, 0400, 'key mode 400';

  $asset = $sslmaker->with_config(make_csr => $intermediate_args);
  ok -e $asset, 'intermediate csr created';
  is $asset, $intermediate_args->{csr}, 'correct asset location';
  is +(stat $asset)[2] & 0777, 0400, 'csr mode 400';

  $asset = $sslmaker->with_config(sign_csr => {
              home => $intermediate_home,
              csr => $intermediate_args->{csr},
              ca_key => $ca_args->{key},
              ca_cert => $ca_args->{cert},
              passphrase => $ca_args->{passphrase},
              extensions => 'v3_ca',
            });

  ok -e $asset, 'csr was signed with ca key';
  $asset->move($intermediate_home->child('certs/intermediate.cert.pem'));
  undef $sslmaker;
  undef $asset;
  ok -e $intermediate_home->child('certs/intermediate.cert.pem'), 'intermediate cert was moved from temp location';

  local $TODO = 'should this be ca_home index.txt and serial?';
  like $intermediate_home->child('index.txt')->slurp, qr{CN=test\.example\.com}, 'cert was added to index.txt';
  like $intermediate_home->child('serial')->slurp, qr{^1001$}m, 'serial was modified';
}

done_testing;
