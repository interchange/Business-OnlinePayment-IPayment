use 5.010001;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Spec;

plan tests => 10;

use Business::OnlinePayment::IPayment;

diag "Create the object and store the fixed values";

# first try with faulty data

my %faulty = ();

my $faultybopi;

eval { $faultybopi =
         Business::OnlinePayment::IPayment->new();
       $faultybopi->session_id;
       };

ok($@, "Error: $@");

my %accdata = (
               accountId => 99999,
               trxuserId => 99999,
               trxpassword =>0,
               adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe',
              );

$faulty{wsdl_file} = File::Spec->catfile(t => "ipayment.wsdl");

# incrementally add the data to the hash

# please note that we want to die here, as without the credentials is
# not going to work, and should be provided when the object is
# created.
foreach my $k (qw/accountId trxuserId trxpassword/) {
    eval { $faultybopi =
             Business::OnlinePayment::IPayment->new(%faulty);
           $faultybopi->session_id;
       };
    # test all the bad values
    ok($@, "Error: $@");
    $faulty{$k} = $accdata{$k};
}

# adminactionpassword seems to be optional? But we need only to
# generate the session, nothing more


my $bopi = Business::OnlinePayment::IPayment->new(%accdata,
                                                  wsdl_file => "ipayment.wsdl");


my $expected = {
                accountData => { %accdata }
               };
my %got  = $bopi->accountData;

is_deeply($expected, \%got, "Stored values ok");

eval { $bopi->accountId("999") };
ok($@, "Can't change the account id");

eval { $bopi->trxuserId("999") };
ok($@, "Can't change the trxuserId");

# ok, no point in testing each of those, we trust Moo to do its job




for (1..3) {
    ok($bopi->session_id, "Session: " . $bopi->session_id)
};




