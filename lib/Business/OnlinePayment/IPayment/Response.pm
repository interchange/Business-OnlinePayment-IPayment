package Business::OnlinePayment::IPayment::Response;
use strict;
use warnings;
use Digest::MD5 qw/md5_hex/;
use Moo;

=head1 NAME

Business::OnlinePayment::IPayment - Helper class for Ipayment responses

=cut

=head2 ACCESSORS

=over 4

=item ret_transtime

Time of transaction.

=cut

has ret_transtime           => (is => 'ro');

=item ret_transdate

Date of the transaction.

=cut 

has ret_transdate           => (is => 'ro');

=item ret_errorcode

The error code of 0 means that the transaction was successful. When in
a CGI integration mode parameter redirect_needed returned with the
value 1 is the only means that all data is correct and a redirect must
be running. The return value is meaningful only after a second call.

=cut

has ret_errorcode           => (is => 'ro');

=item redirect_needed

This parameter is set if the payment could not be completed because of
a redirect necessary.

=cut


=item ret_errormsg

Error message (in German). This is important to propagate to the web
interface.

=cut

has ret_errormsg            => (is => 'ro');


=item ret_additionalmsg

Additional Error message, sometimes in English, sometimes inexistent.

=cut

has ret_additionalmsg => (is => 'ro');

=item ret_fatalerror

This value is returned only if an error has occurred.

Based on this value, your shop offer the buyer the option of payment
data correct as long as there is no fatal error. Fatal errors are
usually disruptions in Bank network or other problems where a new
trial is expected no Improvement brings. Your customers, you can in
this case, a specific error message

=cut

has ret_fatalerror          => (is => 'ro');


has redirect_needed         => (is => 'ro');

=item addr_name

Data type: string, maximum 100 characters
Name of the buyer. This parameter is required for all payments.

=cut

has addr_name               => (is => 'ro');

=item trx_paymentmethod

In this parameter the name of the medium used, payment will be
returned. the For example, a credit card type (such as Visa or
MasterCard) or ELV.

=cut

has trx_paymentmethod       => (is => 'ro');

=item ret_authcode            

Authorization number of third party payment for this transaction or
other unique Identification of the payment the payment provider. The
parameters may in certain cases be empty.

=cut

has ret_authcode            => (is => 'ro');


=item trx_currency            

Currency in which the payment is processed. There are all known
three-letter ISO Currency codes allowed. A list of known currency
codes, see L<https://ipayment.de/> under B<Technik>.

Note that the processing of payments in the currency must be agreed
with your payment provider.


=cut

has trx_currency            => (is => 'ro');


=item ret_url_checksum        

=cut

has ret_url_checksum        => (is => 'ro');


=item ret_param_checksum      

=cut

has ret_param_checksum      => (is => 'ro');


=item ret_ip                  

IP of the client who did the transaction

=cut

has ret_ip                  => (is => 'ro');


=item trx_typ                 

See C<transactionType> in L<Business::OnlinePayment::IPayment>

=cut

has trx_typ                 => (is => 'ro');


=item ret_trx_number          

If the status is C<SUCCESS>, here we have the Unique transaction
number (reservation number) of ipayment system. this number is
returned in the form of "x-xxxxxxx", where x is a single digit. with
this Transaction number, you can perform other actions such as
charging or cancellations.

=cut

has ret_trx_number          => (is => 'ro');


=item ret_status              

The possible values ​​are:

C<SUCCESS>: The transaction has been successfully completed.

C<ERROR>: In transaction processing, an error occurred.

C<REDIRECT>: To further processing must be performed a redirect (3-D
secure, verification needed)

=cut

has ret_status              => (is => 'ro');


=item trx_paymenttyp          

Values: C<cc> (Credit card), C<elv> (ELV), C<pp> (Prepaid payment)

=cut

has trx_paymenttyp          => (is => 'ro');


=item trx_paymentdata_country 

In this parameter, if possible, the ISO code of the country returned
to the the payment data belongs. The field contains, for example, for
credit card payments, the country the card-issuing bank and ELV
payments the bank country.

=cut

has trx_paymentdata_country => (is => 'ro');


=item trx_amount              

Amount to be debited. Enter the value in the B<smallest currency
unit>, for Example cents. B<Decimal points> or other characters except
numbers are B<not allowed>.

For example, the amount of EUR 10.00 is given as 1000 cents.

=cut

has trx_amount              => (is => 'ro');


=item ret_booknr              

Used for the checksum and apparently not documented.

=cut

has ret_booknr              => (is => 'ro');


=item trxuser_id              

See C<trxuserId> in Business::OnlinePayment::IPayment

=cut

has trxuser_id              => (is => 'ro');


=item trx_remoteip_countr

Iso code of the IP which does the transaction

=back

=cut

has trx_remoteip_country    => (is => 'ro');

sub is_success {
    my $self = shift;
    if ($self->ret_status eq 'SUCCESS') {
        return 1;
    }
    else {
        return undef;
    }
}

### HERE WE CAN ADD SOME SHORTCUTS FOR THE SHOP, so we can extract the
### interesting parameters

1;




