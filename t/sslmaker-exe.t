use strict;
use Path::Tiny 'path';
use Test::More;

$ENV{SSLMAKER_SUBJECT} = '/C=US/ST=Texas/L=Dallas/O=Company/OU=Department/CN=superduper';

plan skip_all => 'linux is required' unless $^O eq 'linux';
plan skip_all => 'openssl is required' if system 'openssl -h 2>/dev/null';

my $root = path('local/sslmaker-exe');
my $script;

{
  local @ARGV = qw( --silent );
  $script = do 'script/sslmaker' or plan skip_all => $@;
  $script->bits(1024); # speed up testing
  $script->silent(1);
  $root->remove_tree({safe => 0});
  $root->mkpath;
  ok !-d $root->child('CA'), 'nothing exists';
}

{
  diag 'sslmaker root';
  $script->home($root->child('CA'));
  $script->run('root');
  ok -e $root->child('CA/certs/ca.cert.pem'), 'CA/certs/ca.cert.pem';
  ok -e $root->child('CA/index.txt'), 'CA/index.txt';
  ok -e $root->child('CA/private/ca.key.pem'), 'CA/private/ca.key.pem';
  ok -e $root->child('CA/private/passphrase'), 'CA/private/passphrase';
  ok -e $root->child('CA/serial'), 'CA/serial';
}

{
  diag 'sslmaker intermediate';
  $script->root_home($root->child('CA'));
  $script->home($root->child('intermediate'));
  $script->run('intermediate');
  ok -e $root->child('intermediate/certs/intermediate.cert.pem'), 'intermediate/certs/intermediate.cert.pem';
  ok -e $root->child('intermediate/certs/intermediate.csr.pem'), 'intermediate/certs/intermediate.csr.pem';
  ok -e $root->child('intermediate/certs/ca-chain.cert.pem'), 'intermediate/certs/ca-chain.cert.pem';
  ok -e $root->child('intermediate/index.txt'), 'intermediate/index.txt';
  ok -e $root->child('intermediate/private/intermediate.key.pem'), 'intermediate/private/intermediate.key.pem';
  ok -e $root->child('intermediate/private/passphrase'), 'intermediate/private/passphrase';
  ok -e $root->child('intermediate/serial'), 'intermediate/serial';
}

{
  diag 'sslmaker generate example.com';
  $script->root_home('');
  $script->run(qw( generate example.com ));
  ok -e 'example.com.key.pem', 'example.com.key.pem';
  ok -e 'example.com.csr.pem', 'example.com.csr.pem';
  ok !-e 'example.com.cert.pem', 'example.com.cert.pem need to be created by intermediate';

  diag 'sslmaker sign example.com.csr.pem';
  $script->root_home('');
  $script->run(qw( sign example.com.csr.pem ));
  ok -e 'example.com.cert.pem', 'example.com.cert.pem was created by intermediate';

  unlink qw( example.com.cert.pem example.com.csr.pem example.com.key.pem );
}

done_testing;
