package HTTP::Response::Switch;
# ABSTRACT: handle many HTTP response possibilities

=for stopwords CSV customise

=head1 SYNOPSIS

Define a "dispatcher" for the application code to use directly:

    package MyProject::WebResponses;
    use Moose;
    with 'HTTP::Response::Switch';

    # All of the handlers are defined under this namespace.
    sub handler_namespace { 'MyProject::WebResponse' }

    # Always resort to these handlers before giving up on a response.
    sub default_handlers { qw( ConfirmAction LoginForm ) }

    # Throw an exception of this class if the response can't be handled
    # by any of the specified handlers.
    sub default_exception { 'MyProject::Error::BadWebResponse' }

    # Load all of the handlers and the exception class at compile time
    # (recommended).
    __PACKAGE__->load_classes;

Then, in code that actually talks to the web server:

    my $http_response = WWW::Mechanize->new->post( URL, USER_DATA );

    # Either the right data will be returned, or there was a problem
    # with some user data, or the session got logged out, or the system
    # is down for maintenance, or something entirely unanticipated will
    # happen.  Whatever the case, do the right thing.
    use TryCatch;
    try {
        my @expected_data = MyProject::WebResponses->handle(
            $http_response,
            qw{ RawDataPage RawDataForm },
        );
        return SOMETHING_BUILT_FROM( @expected_data );
    }
    catch (MyProject::Error::NeedConfirmation $e) {
        CLICK_YES;
        TRY_AGAIN;
    }
    catch (MyProject::Error::NotLoggedIn $e) {
        LOG_BACK_IN;
        TRY_AGAIN;
    }

    # Don't catch all possible exceptions here; let calling code decide
    # what to do in some cases.

Also define each handler:

    package MyProject::WebResponse::ConfirmAction;  ...
    package MyProject::WebResponse::LoginForm;      ...
    package MyProject::WebResponse::RawDataPage;    ...
    package MyProject::WebResponse::RawDataForm;    ...

See L<HTTP::Response::Switch::Handler/SYNOPSIS> for example handler
definitions.

=head1 DESCRIPTION

Sometimes the only possible way to communicate with an online service
is through a web application intended for human consumption--dealing
with cookies, forms and parsing of HTML, perhaps with the help of
L<WWW::Mechanize> and L<Web::Scraper>.

When automating such a web application, it may be unsafe to assume that
a specific request will always trigger a specific response.  For
example, requesting bank transactions from an Internet Banking server
could result in a response containing:

=for :list
1.  a CSV file of bank transactions (the "expected" response);
2.  an HTML page indicating an input error and presenting a form;
3.  an HTML page indicating that the session has been terminated;
4.  an HTML page indicating an Internal Server Error; or
5.  something else entirely unanticipated.

Some of those "unexpected" or "undesired" responses may require special
behaviour, in which case it isn't appropriate to simply C<die> on such
responses.  Moreover, some of those responses could potentially occur
on any communication with the web application, creating the need to
test for them at every single point that the web server is contacted.

This distribution aims to abstract away some of the code verbosity that
would be required for this by providing L<Moose> roles for:

=over 4

=item 1.

L<"Handler"|HTTP::Response::Switch::Handler> classes, which look at a
specific L<HTTP::Response> object with a single concern in mind and
either return structured data, throw an exception, or indicate that
they don't know how to handle that specific response.

=item 2.

A "dispatcher" class which takes an L<HTTP::Response> object and passes
it through a chain of the aforementioned "handler" classes until one of
them returns structured data or throws an exception; or, if none of
them do, indicates that that specific response truly is "unexpected."

=back

=head1 USAGE

Refer to the L</SYNOPSIS> above.  Further information on configuring a
"dispatcher" class follows in subsequent sections.  See
L<HTTP::Response::Switch::Handler> for further information on writing
"handler" classes.

In order to better understand how this distribution's code is intended
to be used, inspecting the source code of the following known dependent
distributions may also be helpful:

=for :list
* L<Finance::Bank::Bankwest> v1.2.2 and later

=cut

use Moose::Role;
use namespace::autoclean;

use HTTP::Response::Switch::HandlerDeclinedResponse ();
use Module::Find ();
use Module::Load ();
use TryCatch 1.001000; # for bug fix; imports "try" and "catch"

=head1 METHODS TO DEFINE IN CONSUMING CLASSES

These methods can be defined in a consuming class in order to customise
functionality provided by the role.  Some of these methods must be
defined in order for the consuming class to work.

=head2 handler_namespace

    sub handler_namespace { 'MyProject::WebResponse' }

The namespace under which
L<handler classes|HTTP::Response::Switch::Handler> are to be found.
This method must be defined in every consuming class.

=cut

requires 'handler_namespace';

=head2 default_handlers

    sub default_handlers { qw( LoginForm ) }

A list of
L<handler classes|HTTP::Response::Switch::Handler> (minus the
L</handler_namespace>) that should be asked to process an
L<HTTP::Response> if no other handler accepts the response first.  If
not defined in the consuming class, an empty list is assumed.

=cut

sub default_handlers { () }

=head2 default_exception

    sub default_exception { 'MyProject::Error::BadWebResponse' }
    sub default_exception { die 'unexpected HTTP response' } # default

The exception class to throw if, during a call to L</handle> by
external code, no handlers accept the L<HTTP::Response> in question.
The instance of this class will be passed the HTTP response object when
created, via parameter C<response>.

Alternatively, this method can be written to throw an exception
directly (e.g. using C<die>).

If not defined in the consuming class, the default behaviour in this
situation is to just C<die> with the message C<unexpected HTTP
response>.

The L<Throwable> distribution is suggested for building object-oriented
exception classes.

=cut

sub default_exception { die 'unexpected HTTP response' }

=head1 METHODS AVAILABLE FROM WITHIN CONSUMING CLASSES

These methods are intended only to be called on a consuming class by
that class itself, and not by code external to the class.

=head2 load_classes

    __PACKAGE__->load_classes;

Use L<Module::Find> to locate all of the modules under the
L</handler_namespace> and load them into memory.  Also load the
L</default_exception> class if one is specified.

The handler modules must be loaded into memory before the first call to
L</handle> occurs.  Loading them at compile time is recommended; to do
this, call C<load_classes> within the consuming class in the manner
shown above, outside all C<sub> definitions.

=cut

sub load_classes {
    my $class = shift;

    # Load all of the classes under the handler_namespace.
    Module::Find::useall($class->handler_namespace);

    # If the "default_exception" method returns a string then treat it
    # as an exception class.  Ignore any failures, because any failures
    # are probably by design (e.g. the default implementation).
    my $exception_class;
    Module::Load::load($exception_class)
        if eval { $exception_class = $class->default_exception; 1 };
}

=head2 load_handlers

A deprecated alias for L</load_classes>.  Historically,
C<load_handlers> did not load the L</default_exception> class.

=cut

sub load_handlers { goto &load_classes; }

=head1 METHODS AVAILABLE TO CALLERS OF CONSUMING CLASSES

These methods are intended to be called directly on a consuming class
by code external to the class.

=head2 handle

    my @ret = MyDispatcher->handle( $http_response, @handlers );

Pass the L<HTTP::Response> object in C<$http_response> to each
L<handler class|HTTP::Response::Switch::Handler> defined in
C<@handlers> (if any, and minus the L</handler_namespace>), then to
each of the L</default_handlers>, until one of the handlers accepts the
response for handling and either returns appropriate data or throws an
appropriate exception.

If none of the handlers accept this C<$http_response>, throw the
L</default_exception>.

All of the handler classes (and the L</default_exception> class) are
assumed to have been loaded into memory I<before> this method is first
called.  See L</load_classes>.

=cut

sub handle {
    my ($class, $res, @handlers) = @_;

    for my $handler (@handlers, $class->default_handlers) {
        try {
            my $handler_class
                = $class->handler_namespace . '::' . $handler;
            return $handler_class->new({ response => $res })->handle;
        }
        catch (HTTP::Response::Switch::HandlerDeclinedResponse $e) {
            # This handler declined to handle this response.
            # Move on to the next handler.
        }
    }

    # All of the specified handlers declined to handle the response.
    die $class->default_exception->new({ response => $res });
}

=head1 SEE ALSO

L<HTTP::Response::Switch::Handler>

=cut

1;
