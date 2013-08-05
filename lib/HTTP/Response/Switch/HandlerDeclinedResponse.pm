package HTTP::Response::Switch::HandlerDeclinedResponse;
# ABSTRACT: unrecognised HTTP::Response exception class

=for stopwords unrecognised

=head1 SYNOPSIS

    use TryCatch;
    try {
        HTTP::Response::Switch::HandlerDeclinedResponse->throw;
    }
    catch (
        HTTP::Response::Switch::HandlerDeclinedResponse $e
    ) {
        warn "caught HandlerDeclinedResponse exception: $e";
    }

=head1 DESCRIPTION

Objects of classes consuming the L<HTTP::Response::Switch::Handler>
role throw this exception (via their
L<"decline"|HTTP::Response::Switch::Handler/decline> method) when they
determine that they cannot handle the type of L<HTTP::Response> object
passed to them in this instance.

This exception is internal to L<HTTP::Response::Switch> and will never
propagate past classes consuming that role.  They should only need to
be directly caught when verifying
L<"decline"|HTTP::Response::Switch::Handler/decline> behaviour in unit
tests for L<HTTP::Response::Switch::Handler> implementations.

=cut

use Moose;
use namespace::autoclean;

use Throwable 0.200001 (); # for correct prerequisites
with 'Throwable';

__PACKAGE__->meta->make_immutable;
1;
