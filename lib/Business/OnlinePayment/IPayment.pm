package Business::OnlinePayment::IPayment;

use 5.010001;
use strict;
use warnings FATAL => 'all';
use Moo;

# preparation
use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;

=head1 NAME

Business::OnlinePayment::IPayment - Checkout via Ipayment Silent Mode

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Business::OnlinePayment::IPayment;
    my $foo = Business::OnlinePayment::IPayment->new();


=head2 ACCESSORS

=head3 Fixed values (AccountData)

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
    my %account_data = (
                        accountId => $self->accountId,
                        trxuserId => $self->trxuserId,
                        trxpassword => $self->trxpassword,
                        adminactionpassword => $self->adminactionpassword
                       );
    return (accountData => \%account_data);      
}

=back



=head3 TransactionData

=over 4

=item trxCurrency

Currency in which the payment is processed. There are all known
three-letter ISO Currency codes allowed. A list of known currency
codes, see L<https://ipayment.de/> under B<Technik>. E.g C<EUR>

=cut

has trxCurrency => (is => 'ro');


=item trxAmount

Amount to be debited, in the B<smallest currency unit>, for Example
cents. B<Decimal points> or other characters except numbers are 
B<not allowed>.

=cut

has trxAmount => (is => 'ro');

=item avail_trx_type

The following transaction types are allowed (for Silent Mode):

     preauth
     auth
     base_check
     check_save
     voice_auth
     voice_grefund_cap
     re_preauth
     re_auth
     capture
     reverse
     refund_cap
     grefund_cap

=cut

has avail_trx_type => (is => 'ro',
                       default => sub {
                           return {
                                   preauth => 1,
                                   auth => 1,
                                   base_check => 1,
                                   check_save => 1,
                                   voice_auth => 1,
                                   voice_grefund_cap => 1,
                                   re_preauth => 1,
                                   re_auth => 1,
                                   capture => 1,
                                   reverse => 1,
                                   refund_cap => 1,
                                   grefund_cap => 1,
                                  }
                             });

=item transactionType

The transaction type, choosen from the above types

=cut

has transactionType => (is => 'ro');

=back

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
    my ($res, $trace) =  $self->soap->($self->accountData);

    # check if we got something valuable
    unless ($res and
            ref($res) eq 'HASH' and 
            exists $res->{createSessionResponse}->{sessionId}) {
        # ok, we got an error. Save the trace to the error and return
        $self->_set_error($trace);
        return undef;
    }

    # still here? good!
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
