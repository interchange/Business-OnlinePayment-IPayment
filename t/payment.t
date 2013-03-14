use 5.010001;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Spec;
use LWP::UserAgent;
use URI;

plan tests => 25;

use Business::OnlinePayment::IPayment;
use Business::OnlinePayment::IPayment::Response;

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
               trxpassword => 0,
               adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe',
              );

my %urls = (
            success_url => "http://linuxia.de/ipayment/success",
            failure_url => "http://linuxia.de/ipayment/failure",
           );

$faulty{wsdl_file} = File::Spec->catfile("t", "ipayment.wsdl");

# incrementally add the data to the hash

# please note that we want to die here, as without the credentials is
# not going to work, and should be provided when the object is
# created.
foreach my $k (qw/accountId trxuserId trxpassword/) {
    eval { $faultybopi =
             Business::OnlinePayment::IPayment->new(%faulty, %urls);
           $faultybopi->session_id;
       };
    # test all the bad values
    ok($@, "Error: $@");
    $faulty{$k} = $accdata{$k};
}

# adminactionpassword seems to be optional? But we need only to
# generate the session, nothing more

my $wsdl_file = File::Spec->catfile("t", "ipayment.wsdl");

my $bopi = Business::OnlinePayment::IPayment->new(%accdata, %urls,
                                                  wsdl_file => $wsdl_file);


is_deeply($bopi->accountData, { %accdata } , "Stored values ok");

is scalar(keys %{$bopi->processorUrls}), 2, "Found two urls";
is $bopi->processorUrls->{redirectUrl}, $urls{success_url}, "success ok";
is $bopi->processorUrls->{silentErrorUrl}, $urls{failure_url}, "success ok";

eval { $bopi->accountId("999") };
ok($@, "Can't change the account id $@");

eval { $bopi->trxuserId("999") };
ok($@, "Can't change the trxuserId $@");

eval { $bopi->paymentType("test") };
ok($@, "Can't set payment type to bogus value $@");

eval { $bopi->transactionType("preauth") };
ok(!$@, "Can change the transaction to allowed value");

eval { $bopi->transactionType("test") };
ok($@, "Can't set payment type to bogus value $@");



# ok, no point in testing each of those, we trust Moo to do its job

$bopi->transactionType('preauth');
$bopi->trxAmount(1000); # 10 euros



my $session_id = $bopi->session_id;

my $ua = LWP::UserAgent->new;
$ua->max_redirect(0);

my $response = $ua->post($bopi->ipayment_cgi_location,,
                         { ipayment_session_id => $session_id,
                           addr_name => "Mario Rossi",
                           silent => 1,
                           cc_number => "371449635398431",
                           cc_checkcode => "",
                           cc_expdate_month => "02",
                           cc_expdate_year => "2014" });

test_success($response);


diag "Testing secured app";


my %account = (
               accountId => 99999,
               trxuserId => 99998,
               trxpassword => 0,
               adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe',
               app_security_key => 'testtest',
               wsdl_file => $wsdl_file,
               %urls
              );


my $secbopi = Business::OnlinePayment::IPayment->new(%account);
$secbopi->transactionType('preauth');
$secbopi->trxAmount(5000); # 50 euros

$response = $ua->post($secbopi->ipayment_cgi_location,
                      { ipayment_session_id => $secbopi->session_id,
                        addr_name => "Mario Pegula",
                        silent => 1,
                        cc_number => "4111111111111111",
                        cc_checkcode => "",
                        cc_expdate_month => "02",
                        trx_securityhash => $secbopi->trx_securityhash,
                        cc_expdate_year => "2014" });

# diag Dumper($response->header('location'));
test_success($response);

my $ipayres = $secbopi->get_response_obj($response->header('location'));

# we build this anew, as in the web it will be a fresh request, so we
# don't do nothing about the previous one.

$ipayres->set_credentials(
                          my_amount   => $secbopi->trxAmount,
                          my_currency => $secbopi->trxCurrency,
                          my_userid   => $secbopi->trxuserId,
                          my_security_key => $secbopi->app_security_key,
                         );

ok($ipayres->is_valid, "Payment looks ok");

# while if we tamper fails
$ipayres->my_amount(5000000);
ok(!$ipayres->is_valid, "Tampered data not ok");

# passing only the security key should work too
my $location = URI->new($response->header('location'));
my %params = $location->query_form;

$ipayres = Business::OnlinePayment::IPayment::Response->new(%params);
eval {$ipayres->is_valid };
ok($@, "no secret key: $@");

# with security key pass is ok.
$ipayres = Business::OnlinePayment::IPayment::Response->new(%params);
$ipayres->my_security_key("testtest");
ok($ipayres->is_success && $ipayres->is_valid, "Payment looks ok");
ok($ipayres->url_is_valid($response->header('location')),
   "Url looks untampered");

$ipayres->my_security_key("testtestX");
ok(!$ipayres->is_valid, "wrong secret key yields failure");





diag "Please wait 2 minutes before running me again, or the tests will fail!";

sub test_success {
    my $r = shift;
    is($r->status_line, '302 Found', "We are redirected");
    unlike($r->decoded_content, qr/ERROR/, "No error");
    like($r->decoded_content, qr/<a href="http:/, "Redirect");
    my $uri = URI->new($r->header('location'));
    # my %result = $uri->query_form;
    # print Dumper(\%result);
}
