use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Spec;
use LWP::UserAgent;
use URI;



use Business::OnlinePayment::IPayment;
use Business::OnlinePayment::IPayment::Return;
use Business::OnlinePayment::IPayment::Response;
my $ua = LWP::UserAgent->new;
$ua->max_redirect(0);

plan tests => 22;

my %account = (
               accountid => 99999,
               trxuserid => 99998,
               trxpassword => 0,
               adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe',
               app_security_key => 'testtest',
               wsdl_file => File::Spec->catfile("t", "ipayment.wsdl"),
               success_url => "http://linuxia.de/ipayment/success",
               failure_url => "http://linuxia.de/ipayment/failure",
              );
my $secbopi = Business::OnlinePayment::IPayment->new(%account);

my $amount = int(rand(5000)) * 100 + 2000;

my $shopper_id = int(rand(5000));

$secbopi->transaction(transactionType => 'preauth',
                      trxAmount       => "$amount",
                      shopper_id      => $shopper_id);

my $response = $ua->post($secbopi->ipayment_cgi_location,
                      { ipayment_session_id => $secbopi->session_id,
                        addr_name => "Mario Pegula",
                        silent => 1,
                        cc_number => "4111111111111111",
                        cc_checkcode => "",
                        cc_expdate_month => "02",
                        cc_expdate_year => "2014",
                        trx_securityhash => $secbopi->trx_securityhash,
                        # the following is the purpose of the testing
                        use_datastorage => 1,
                        datastorage_expirydate => '2013/07/12',
                      });

my $params = URI->new($response->header('location'));
print Dumper({ $params->query_form });

my $ipayres = $secbopi->get_response_obj($response->header('location'));

ok($ipayres->is_valid);
ok($ipayres->is_success);
# print Dumper($ipayres);
ok($ipayres->storage_id, "Got the storage id: " . $ipayres->storage_id);
is($ipayres->datastorage_expirydate, "2013/07/12");

# do a new transaction using the data storage
$amount = int(rand(5000)) * 100 + 2000;

$shopper_id = int(rand(5000));

my $storage_id = $ipayres->storage_id;

$secbopi->transaction(transactionType => 'preauth',
                      trxAmount       => "$amount",
                      shopper_id      => $shopper_id);

my $ret = $secbopi->datastorage_op($storage_id);
print Dumper($secbopi->raw_response_hash);

my $exp = { storage_id => $storage_id };

test_return_obj($ret, $exp);

my $capt = $secbopi->capture($ret->ret_trx_number);
ok($capt->is_success, "Capturing successed");
print Dumper($capt);




$amount = int(rand(5000)) * 100 + 2000;
$shopper_id = int(rand(5000));
$secbopi->transaction(transactionType => 'auth',
                      trxAmount       => "$amount",
                      shopper_id      => $shopper_id);

$ret = $secbopi->datastorage_op($storage_id);
print Dumper($secbopi->raw_response_hash);

test_return_obj($ret, $exp);

$secbopi->transaction(transactionType => 'preauth',
                      trxAmount       => "1000000",
                      shopper_id      => "XXXX123432XX");

$ret = $secbopi->datastorage_op('123456');
ok($ret, "Got an object from the fake request");
ok(!$ret->is_success, "But it's not a success");
print Dumper($ret->errorDetails);
ok($ret->error_info);




sub test_return_obj {
    my ($obj, $exp) = @_;
    ok($ret->is_success, "is success");
    is($ret->trx_paymentmethod, "VisaCard", "fake Visa");
    ok($ret->trx_remoteip_country, "got remote country: " . $ret->trx_remoteip_country);
    ok($ret->trx_paymentdata_country, "got remote payment country: " . $ret->trx_paymentdata_country);
    is($ret->storage_id, $exp->{storage_id}, $exp->{storage_id} . " ok");
    ok($ret->trx_timestamp, "Timestamp: " . $ret->trx_timestamp);
    ok($ret->ret_trx_number, "trx number: " .$ret->ret_trx_number);
}
