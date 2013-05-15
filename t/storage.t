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

plan tests => 4;

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
