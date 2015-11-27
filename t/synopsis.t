use strict;
use Test::More;
use App::sslmaker;

plan skip_all => 'Cannot build on Win32' if $^O eq 'MSWin32';

my $sslmaker = App::sslmaker->new(subject => '/C=US/ST=Gotham/L=Gotham/O=Wayne Enterprises/OU=Batcave/CN=batman');
my $key = $sslmaker->make_key;
ok -s $key, 'key generated';

my $csr = $sslmaker->make_csr({ key => $key->path });
ok -s $csr, 'csr generated';

done_testing;
