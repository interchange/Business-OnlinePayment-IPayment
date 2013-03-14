package Business::OnlinePayment::IPayment;

use 5.010001;
use strict;
use warnings;

# preparation
use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;
use Business::OnlinePayment::IPayment::Response;
use Scalar::Util qw/looks_like_number/;
use Digest::MD5 qw/md5_hex/;
use URI;

use Moo;


# use Log::Report mode => 'DEBUG';

=head1 NAME

Business::OnlinePayment::IPayment - Checkout via Ipayment Silent Mode

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

  use Business::OnlinePayment::IPayment;
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
  
  $response = $ua->post('https://ipayment.de/merchant/99999/processor/2.0/',
                        { ipayment_session_id => $secbopi->session_id,
                          addr_name => "Mario Pegula",
                          silent => 1,
                          cc_number => "4111111111111111",
                          cc_checkcode => "",
                          cc_expdate_month => "02",
                          trx_securityhash => $secbopi->trx_securityhash,
                          cc_expdate_year => "2014" });
  
  
=head2 ACCESSORS

=head3 Fixed values (accountData and processorUrls)

The following attributes should and can be set only in the
constructor, as they are pretty much fixed values.

=over 4

=item wsdl_file

The name of th WSDL file. It should be a local file.

=cut

has wsdl_file => (is => 'ro');

=item accountId

The Ipayment account id (the one put into the CGI url)

=cut

has accountId => (is => 'ro');

=item trxuserId

The application ID, you can in your ipayment configuration menu read
using  Anwendung > Details 

=cut

has trxuserId => (is => 'ro');

=item trxpassword

For each application, there is an application password which
automatically ipayment System is presented. The password consists of
numbers. You will find the application password in your ipayment
Anwendungen > Details

B<This is not the account password!>

=cut

has trxpassword => (is => 'ro');

=item adminactionpassword

The admin password.

B<This is not the account password!>

=cut 

has adminactionpassword => (is => 'ro');


=item app_security_key

If this attribute is set, we will (and shall) send a checksum for the
parameters.

B<Without this, we are opened to tampering>

=cut

has app_security_key => (is => 'ro');


=item accountData

Accessor to retrieve the hash with the account data details. The
output will look like this:

 accountData => {
                 accountId => 99999,
                 trxuserId => 99999,
                 trxpassword =>0,
                 adminactionpassword => '5cfgRT34xsdedtFLdfHxj7tfwx24fe'}


=cut

sub accountData {
    my $self = shift;
    my %account_data = (  # mandatory
                        accountId => $self->accountId,
                        trxuserId => $self->trxuserId,
                        trxpassword => $self->trxpassword
                        );
    my $adminpass = $self->adminactionpassword;
    if (defined $adminpass) {
        $account_data{adminactionpassword} = $adminpass;
    }
    return \%account_data;
}

=item success_url 

Mandatory (for us) field, where to redirect the user in case of success.

=cut

has success_url => (is => 'ro',
                    isa => sub { die "Missing success url" unless $_[0] },
                    default => sub { die "Missing success url" },
                   );

=item failure_url

Mandatory (for us) field, where to redirect the user in case of failure.

=cut

has failure_url => (is => 'ro',
                    isa => sub { die "Missing failure url" unless $_[0] },
                    default => sub { die "Missing success url" },
                   );


=item hidden_trigger

Optional url for the hidden trigger.

=cut

has hidden_trigger => (is => 'ro');


=item processorUrls

Return the hashref with the defined urls

=back

=cut

sub processorUrls {
    my $self = shift;
    my %urls = (
                redirectUrl => $self->success_url,
               );
    if ($self->failure_url) {
        $urls{silentErrorUrl} = $self->failure_url,
    }
    if ($self->hidden_trigger) {
        $urls{hiddenTriggerUrl} = $self->hidden_trigger
    }
    return \%urls
}



=head3 TransactionData

These fields could be filled on the fly, but given that we want to add
security, we do some additional checks here


=over 4

=item trxCurrency

Currency in which the payment is processed. There are all known
three-letter ISO Currency codes allowed. A list of known currency
codes, see L<https://ipayment.de/> under B<Technik>. E.g C<EUR>

=cut

has trxCurrency => (is => 'rw',
                    default => sub { return 'EUR'},
                    isa => sub {
                        die "Only one argument for trxCurrency" unless @_ == 1;
                        die "Wrong currency" unless $_[0] =~ m/^[A-Z]{3}$/s;
                    });


=item trxAmount

Amount to be debited, in the B<smallest currency unit>, for Example
cents. B<Decimal points> or other characters except numbers are 
B<not allowed>.

=cut

has trxAmount => (is => 'rw',
                  default => sub { return 0 },
                  isa => sub {
                      die "Not a number" unless looks_like_number($_[0]);
                      my $num = $_[0];
                      my $int = int($num);
                      die unless $num eq $int # string-wise operation
                  });


=item shopper_id

This parameter allows you to specify a unique ID for an order process.
Under this Shopper ID is saved to the associated transaction in order
ipayment system. The Shopper ID must be unique only if the extended
examination of the IDs Avoidance of double use transactions.

=cut

has shopper_id => (is => 'rw');

=item transactionData

Return the hashref with the transaction data details

=cut


sub transactionData {
    my $self = shift;
    my %trx = (
               trxAmount => $self->trxAmount,
               trxCurrency => $self->trxCurrency,
              );
    if ($self->shopper_id) {
        $trx{shopperId} = $self->shopper_id;
    }
    return \%trx;
}


=item transactionType

The transaction type, choosen from the types below. It defaults to C<auth>

  preauth
  auth
  base_check
  check_save
  grefund_cap


=cut

has transactionType => (is => 'rw',
                        default => sub { return "auth" },
                        isa => sub {
                            my %avail = (
                                         preauth => 1,
                                         auth => 1,
                                         base_check => 1,
                                         check_save => 1,
                                         grefund_cap => 1,
                                        );
                            my $type = $_[0];
                            die "Missing transaction type\n" unless $type;
                            die "Only one arg is supported\n" unless @_ == 1;
                            die "$type not valid\n" unless $avail{$type};
                        }
                       );

=item paymentType

The payment type, choosen from the types below. It defaults to C<cc> 

  cc
  elv
  pp

=back

=cut

has paymentType => (is => 'rw',
                    default => sub { return "cc" },
                    isa => sub {
                        my %avail = (
                                     pp => 1,
                                     cc => 1,
                                     elv => 1,
                                    );
                        my $type = $_[0];
                        die "Missing payment type\n" unless $type;
                        die "Only one arg is supported\n" unless @_ == 1;
                        die "Invalid payment type $type\n" unless $avail{$type};
                    });




=head3 error

This accessors point to a XML::Compile::SOAP backtrace. The object is
quite large and deeply nested, but it's there just in case we need it.

=cut

has error => (is => 'rwp');


=head2 METHODS

=over 4

=item session_id

This is the main method to call. The session is not stored in the object, because it can used only B<once>. So calling session_id will send the data to the SOAP service and retrieve the session key.

=cut

sub session_id {
    my $self = shift;
    # clean eventually stale data
    $self->_set_error(undef);

    # init the soap, if not already
    unless ($self->soap) {
        $self->_init_soap();
    }

    # do the request passing the accountData
    my ($res, $trace) =  $self->soap->(accountData => $self->accountData,
                                       transactionType => $self->transactionType,
                                       paymentType => $self->paymentType,
                                       processorUrls => $self->processorUrls,
                                       transactionData => $self->transactionData,
                                      ); # fixed

    # check if we got something valuable
    unless ($res and
            ref($res) eq 'HASH' and 
            exists $res->{createSessionResponse}->{sessionId}) {
        # ok, we got an error. Save the trace to the error and return
        $self->_set_error($trace);
        return undef;
    }

    return $res->{createSessionResponse}->{sessionId};
    # please note that we don't store the sessionId. It's a fire and forget.
}



=item soap

The SOAP object (used internally)

=cut

has soap => (is => 'rwp');


sub _init_soap {
    my $self = shift;
    my $wsdl = XML::Compile::WSDL11->new($self->wsdl_file);
    # compile the object and store it in soap
    my $client = $wsdl->compileClient('createSession');
    $self->_set_soap($client);
}


=head2 SOAP specification

  Name: createSession
  Binding: ipaymentBinding
  Endpoint: https://ipayment.de/service/3.0/
  SoapAction: createSession
  Input:
    use: literal
    namespace: https://ipayment.de/service_v3/binding
    message: createSessionRequest
    parts:
      accountData: https://ipayment.de/service_v3/extern:AccountData
      transactionData: https://ipayment.de/service_v3/extern:TransactionData
      transactionType: https://ipayment.de/service_v3/extern:TransactionType
      paymentType: https://ipayment.de/service_v3/extern:PaymentType
      options: https://ipayment.de/service_v3/extern:OptionData
      processorUrls: https://ipayment.de/service_v3/extern:ProcessorUrlData
  Output:
    use: literal
    namespace: https://ipayment.de/service_v3/binding
    message: createSessionResponse
    parts:
      sessionId: http://www.w3.org/2001/XMLSchema:string
  Style: rpc
  Transport: http://schemas.xmlsoap.org/soap/http
  

=back


=head2 SECURITY

=item trx_securityhash

If we have a security key, we trigger the hash generation, so we can
double check the result.

=cut



sub trx_securityhash {
    my $self = shift;
    unless ($self->app_security_key) {
        warn "hash requested, but app_security_key wasn't provided!\n";
        return;
    }
    return md5_hex($self->trxuserId .
                   $self->trxAmount .
                   $self->trxCurrency .
                   $self->trxpassword .
                   $self->app_security_key);
}


=head2 UTILITIES

=head3 validate_result($rawuri) or validate_result(%params)

To be sure the transaction happened as aspected, we have to check this back.
Expected hash:

Success:

  'ret_transtime' => '08:42:05',       'ret_transtime' => '08:42:03',
  'ret_errorcode' => '0',              'ret_errorcode' => '0',
  'redirect_needed' => '0',            'redirect_needed' => '0',
  'ret_transdate' => '14.03.13',       'ret_transdate' => '14.03.13',
  'addr_name' => 'Mario Pegula',       'addr_name' => 'Mario Rossi',
  'trx_paymentmethod' => 'VisaCard',   'trx_paymentmethod' => 'AmexCard',
  'ret_authcode' => '',                'ret_authcode' => '',
  'trx_currency' => 'EUR',             'trx_currency' => 'EUR',
  'ret_url_checksum' => 'md5sum',
  'ret_param_checksum' => 'md5sum',
  'ret_ip' => '88.198.37.147',         'ret_ip' => '88.198.37.147',
  'trx_typ' => 'preauth',              'trx_typ' => 'preauth',
  'ret_trx_number' => '1-83443831',    'ret_trx_number' => '1-83443830',
  'ret_status' => 'SUCCESS',           'ret_status' => 'SUCCESS',
  'trx_paymenttyp' => 'cc',            'trx_paymenttyp' => 'cc',
  'trx_paymentdata_country' => 'US',
  'trx_amount' => '5000',              'trx_amount' => '1000',
  'ret_booknr' => '1-83443831',        'ret_booknr' => '1-83443830',
  'trxuser_id' => '99998',             'trxuser_id' => '99999',
  'trx_remoteip_country' => 'DE'       'trx_remoteip_country' => 'DE'

Returns a Business::OnlinePayment::IPayment::Response object, so you
can call ->is_success on it.

This is just a shortcuts for 

  Business::OnlinePayment::IPayment::Response->new(%params);

=cut

sub get_response_obj {
    my ($self, @args) = @_;
    my %details;
    my $resobj;
    
    # only one argument: we have an URI
    if (@args == 1) {
        my $uri = URI->new(shift(@args));
        $resobj = Business::OnlinePayment::IPayment::Response
          ->new($uri->query_form);
    }
    elsif ((@args % 2) == 0) {
        $resobj = Business::OnlinePayment::IPayment::Response
          ->new(@args);
    }
    else {
        die "Arguments to validate the response not provided "
          . "(paramaters or raw url";
    }
    return $resobj;
}


















=head3 ipayment_cgi_location

Returns the correct url where the customer posts the CC data, which is simply:
L<https://ipayment.de/merchant/<Account-ID>/processor/2.0/>

=cut

sub ipayment_cgi_location {
    my $self = shift;
    return 'https://ipayment.de/merchant/' . $self->accountId
      . '/processor/2.0/';
}


=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-onlinepayment-ipayment at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-OnlinePayment-IPayment>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::OnlinePayment::IPayment


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-OnlinePayment-IPayment>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-OnlinePayment-IPayment>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-OnlinePayment-IPayment>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-OnlinePayment-IPayment/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Marco Pessotto.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Business::OnlinePayment::IPayment
