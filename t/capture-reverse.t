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

my $amount = int(rand(5000)) * 100 + 2;

$secbopi->transaction(transactionType => 'preauth',
                      trxAmount       => "$amount",
                      shopper_id      => 1234);

my $response = $ua->post($secbopi->ipayment_cgi_location,
                      { ipayment_session_id => $secbopi->session_id,
                        addr_name => "Mario Pegula",
                        addr_street => "via del piffero 10",
                        addr_city => "Trieste",
                        addr_zip => "34100",
                        addr_country => "IT",
                        addr_telefon => "041-311234",
                        addr_email => 'melmothx@gmail.com',
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
is($ipayres->address_info, 'Mario Pegula via del piffero 10 34100 Trieste IT melmothx@gmail.com 041-311234',
   "Address OK: " . $ipayres->address_info);

print $ipayres->ret_trx_number, " ", $ipayres->trx_amount, " ", $ipayres->trx_currency, "\n";

my $res = $secbopi->capture($ipayres->ret_trx_number, $amount - 200, "EUR");

ok($res->is_success, "Charging the amount minus 2 euros works");
is($res->status, "SUCCESS");
is(ref($res->successDetails), "HASH");
is($res->paymentMethod, "VisaCard", "Payment method ok");
is($res->trx_paymentmethod, "VisaCard", "Payment method ok (alternate)");
ok($res->trxRemoteIpCountry, "ip ok");
ok($res->trx_remoteip_country, "ip ok (alternate)");
is($res->trx_paymentdata_country, "US", "country ok");
is($res->trxPaymentDataCountry, "US", "country ok");
is($res->address_info, 'via del piffero 10 34100 Trieste IT melmothx@gmail.com 041-311234', "Address OK");
is(ref($res->addressData), "HASH");
ok($res->trx_timestamp, "timestamp ok: " . $res->trx_timestamp);
ok($res->ret_transtime, "time ok: " . $res->ret_transtime);
ok($res->ret_transdate, "date ok: " . $res->ret_transdate);

ok(defined $res->ret_authcode,
   "authcode is defined:" . $res->ret_authcode);

ok($res->ret_trx_number,
   "Trx number is returned: " . $res->ret_trx_number);

$res = $secbopi->capture($ipayres->ret_trx_number, 200 , "EUR");

is($res->address_info, 'via del piffero 10 34100 Trieste IT melmothx@gmail.com 041-311234', "Address OK");

ok($res->is_success, "Charging the remaining 2 euros works");

diag Dumper($res->successDetails);

sleep 1;

$res = $secbopi->capture($ipayres->ret_trx_number, 500000 , "EUR");
# print Dumper($secbopi->debug);

diag Dumper($res->successDetails);

is($res->address_info, '', "Empty address on failure");

ok(!$res->is_success, "More charging fails");
print Dumper ($res);
ok($res->is_error, "And we have an error");

ok($res->error_info =~ qr/Capture nicht m Not enough funds left \(\d+\) for this capture. 10031/, "Not funds left error ok");

$res = $secbopi->capture("828939234", 500000, "EUR");

ok($res->is_error, "Charging a random number with 50.000 fails");

is($res->error_info, "FATAL: Die Initialisierung der Transaktion ist fehlgeschlagen. 1002", "Fatal error displayed correctly");

ok(!$res->trx_timestamp, "timestamp empty: " . $res->trx_timestamp);
ok(!$res->ret_transtime, "time empty: " . $res->ret_transtime);
ok(!$res->ret_transdate, "date empty: " . $res->ret_transdate);

done_testing;




