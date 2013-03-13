use 5.010001;
use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan tests => 4;

use Business::OnlinePayment::IPayment;

diag "Create the object and store the fixed values";

my %accdata = (
               accountId => 99999,
               trxuserId => 99999,
               trxpassword =>0,
               adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe',
              );

my $bopi = Business::OnlinePayment::IPayment->new(%accdata,
                                                  wsdl_file => "ipayment.wsdl");


my $expected = {
                accountData => { %accdata }
               };
my %got  = $bopi->accountData;

is_deeply($expected, \%got);

for (1..3) {
    ok($bopi->session_id, "Session: " . $bopi->session_id)
};




