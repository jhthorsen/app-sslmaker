use strict;
use Test::More;
use App::sslmaker;

plan skip_all => 'Not supported on Win32' if $^O eq 'MSWin32';
plan skip_all => 'Not supported on freebsd' if $^O eq 'freebsd';

my $sslmaker = App::sslmaker->new(subject => '/C=US/ST=Gotham/L=Gotham/O=Wayne Enterprises/OU=Batcave/CN=batman');
my $key = $sslmaker->make_key;
ok -s $key, 'key generated';

my $csr = $sslmaker->make_csr({ key => $key->path });
ok -s $csr, 'csr generated';

done_testing;
