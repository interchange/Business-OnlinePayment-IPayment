use 5.010001;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Spec;
use LWP::UserAgent;
use URI;



use Business::OnlinePayment::IPayment;

my $ua = LWP::UserAgent->new;
$ua->max_redirect(0);


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

my $amount = int(rand(5000)) * 100;

$secbopi->transaction(transactionType => 'preauth',
                      trxAmount       => $amount,
                      shopper_id      => 1234);

my $response = $ua->post($secbopi->ipayment_cgi_location,
                      { ipayment_session_id => $secbopi->session_id,
                        addr_name => "Mario Pegula",
                        addr_country => "DE",
                        silent => 1,
                        cc_number => "4111111111111111",
                        cc_checkcode => "",
                        cc_expdate_month => "02",
                        trx_securityhash => $secbopi->trx_securityhash,
                        cc_expdate_year => "2014" });

# ok($secbopi->debug->request->content, "We can inspect the SOAP request");

# print $secbopi->debug->response->content;

my $ipayres = $secbopi->get_response_obj($response->header('location'));

ok($ipayres->is_valid);
ok($ipayres->is_success);

print $ipayres->ret_trx_number, " ", $ipayres->trx_amount, " ", $ipayres->trx_currency, "\n";

my $res = $secbopi->capture($ipayres->ret_trx_number, $amount - 200, "EUR");

ok($res->is_success, "Charging the amount minus 2 euros works");

$res = $secbopi->capture($ipayres->ret_trx_number, 200 , "EUR");

ok($res->is_success, "Charging the remaining 2 euros works");

$res = $secbopi->capture($ipayres->ret_trx_number, 50000 , "EUR");
# print Dumper($secbopi->debug);

ok(!$res->is_success, "More charging fails");
# print Dumper ($res);
ok($res->is_error, "And we have an error");

done_testing;




