use strict;
use Path::Tiny 'path';
use Test::More;

plan skip_all => "$^O is not supported" if $^O eq 'MSWin32';
plan skip_all => 'openssl is required'  if system 'openssl version >/dev/null';

my @unlink = map {
  my $i = $_;
  map {"client$i.example.com.$_.pem"} qw(cert csr key)
} 1 .. 2;
my $home = path('local/tmp/sslmaker');
my $script;

unlink @unlink;

subtest 'silent' => sub {
  local @ARGV = qw(--silent);
  $script = do './script/sslmaker' or plan skip_all => $@;
  $script->bits(1024);    # speed up testing
  $script->silent(1);
  $home->remove_tree({safe => 0});
  $home->mkpath;
  ok !-d $home->child('root'), 'nothing exists';
};

subtest 'sslmaker root' => sub {
  $script->home($home);
  $script->subject('/C=US/ST=Texas/L=Dallas/O=Company/OU=Department/CN=superduper');
  $script->run('root');
  ok -e $home->child('root/ca.cert.pem'), 'root/ca.cert.pem';
  ok -e $home->child('root/index.txt'),   'index.txt';
  ok -e $home->child('root/ca.key.pem'),  'root/ca.key.pem';
  ok -e $home->child('root/passphrase'),  'root/passphrase';
  ok -e $home->child('root/serial'),      'root/serial';
};

subtest 'sslmaker intermediate' => sub {
  $script->subject('');    # read subject from root CA
  $script->run('intermediate');

  ok -e $home->child('root/ca.cert.pem'), 'root/ca.cert.pem';
  ok -e $home->child('root/index.txt'),   'root/index.txt';
  ok -e $home->child('root/ca.key.pem'),  'root/ca.key.pem';
  ok -e $home->child('root/passphrase'),  'root/passphrase';
  ok -e $home->child('root/serial'),      'root/serial';


  ok -e $home->child('certs/ca.cert.pem'),       'certs/ca.cert.pem';
  ok -e $home->child('certs/ca.csr.pem'),        'certs/ca.csr.pem';
  ok -e $home->child('certs/ca-chain.cert.pem'), 'certs/ca-chain.cert.pem';
  ok -e $home->child('index.txt'),               'index.txt';
  ok -e $home->child('private/ca.key.pem'),      'private/ca.key.pem';
  ok -e $home->child('private/passphrase'),      'private/passphrase';
  ok -e $home->child('serial'),                  'serial';
};

subtest 'sslmaker generate example.com' => sub {
  $script->run(qw(generate client1.example.com));
  $script->run(qw(generate client2.example.com));
  ok -e 'client1.example.com.key.pem', 'client1.example.com.key.pem';
  ok -e 'client1.example.com.csr.pem', 'client1.example.com.csr.pem';
  ok !-e 'client1.example.com.cert.pem',
    'client1.example.com.cert.pem need to be created from intermediate';
};

subtest 'sslmaker sign example.com.csr.pem' => sub {
  $script->run(qw(sign client1.example.com.csr.pem));
  $script->run(qw(sign client2.example.com.csr.pem));
  ok -e 'client2.example.com.cert.pem',
    'client2.example.com.cert.pem was created from intermediate';

  my $index = $home->child('index.txt')->slurp;
  like $index, qr{^V.*CN=client1\.example\.com$}m, 'index.txt has V client1.example.com';
  like $index, qr{^V.*CN=client2\.example\.com$}m, 'index.txt has V client2.example.com';
};

subtest 'sslmaker revoke example.com' => sub {
  $script->run(qw(revoke client2.example.com.cert.pem));
  $script->run(qw(revoke client1.example.com.cert.pem));

  my $index = $home->child('index.txt')->slurp;
  like $index, qr{^R.*CN=client1\.example\.com$}m, 'index.txt has R client1.example.com';
  like $index, qr{^R.*CN=client2\.example\.com$}m, 'index.txt has R client2.example.com';
};

#unlink @unlink;
#$home->remove_tree({safe => 0});
done_testing;
