# $Id$
#
# RT::Client::REST::Ticket -- ticket object representation.

package RT::Client::REST::Ticket;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.09';

use Error qw(:try);
use Params::Validate qw(:types);
use RT::Client::REST 0.18;
use RT::Client::REST::Attachment;
use RT::Client::REST::Object 0.01;
use RT::Client::REST::Object::Exception 0.04;
use RT::Client::REST::SearchResult 0.02;
use RT::Client::REST::Transaction;
use base 'RT::Client::REST::Object';

=head1 NAME

RT::Client::REST::Ticket -- this object represents a ticket.

=head1 SYNOPSIS

  my $rt = RT::Client::REST->new(server => $ENV{RTSERVER});

  # Create a new ticket:
  my $ticket = RT::Client::REST::Ticket->new(
    rt => $rt,
    queue => "General",
    subject => $subject,
  )->store(text => "This is the initial text of the ticket");
  print "Created a new ticket, ID ", $ticket->id, "\n";

  # Update
  my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    id  => $id,
    priority => 10,
  )->store;

  # Retrieve
  my $ticket => RT::Client::REST::Ticket->new(
    rt => $rt,
    id => $id,
  )->new->retrieve;

  unless ($ticket->owner eq $me) {
    $ticket->steal;     # Give me more work!
  }

=head1 DESCRIPTION

B<RT::Client::REST::Ticket> is based on L<RT::Client::REST::Object>.
The representation allows to retrieve, edit, comment on, and create
tickets in RT.

=cut

sub _attributes {{

    id  => {
        validation  => {
            type    => SCALAR,
            regex   => qr/^\d+$/,
        },
        form2value  => sub {
            shift =~ m~^ticket/(\d+)$~i;
            return $1;
        },
        value2form  => sub {
            return 'ticket/' . shift;
        },
    },

    queue   => {
        validation  => {
            type    => SCALAR,
        },
    },

    owner   => {
        validation  => {
            type    => SCALAR,
        },
    },

    creator   => {
        validation  => {
            type    => SCALAR,
        },
    },

    subject => {
        validation  => {
            type    => SCALAR,
        },
    },

    status  => {
        validation  => {
            # That's it for validation...  People can create their own
            # custom statuses.
            type    => SCALAR,
        },
    },

    priority => {
        validation  => {
            type    => SCALAR,
        },
    },

    initial_priority => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'InitialPriority',
    },

    final_priority  => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'FinalPriority',
    },

    requestors      => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
    },

    cc              => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
    },

    admin_cc        => {
        validation  => {
            type    => ARRAYREF,
        },
        list        => 1,
        rest_name   => 'AdminCc',
    },

    created         => {
        validation  => {
            type    => SCALAR,
        },
    },

    starts          => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    started         => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    due             => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    resolved        => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    told            => {
        validation  => {
            type    => SCALAR|UNDEF,
        },
    },

    time_estimated  => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'TimeEstimated',
    },

    time_worked     => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'TimeWorked',
    },

    time_left       => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'TimeLeft',
    },

    last_updated    => {
        validation  => {
            type    => SCALAR,
        },
        rest_name   => 'LastUpdated',
    },
}}

=head1 ATTRIBUTES

=over 2

=item B<id>

This is the numeric ID of the ticket.

=item B<queue>

This is the B<name> of the queue (not numeric id).

=item B<owner>

Username of the owner.

=item B<creator>

Username of RT user who created the ticket.

=item B<subject>

Subject of the ticket.

=item B<status>

The status is usually one of the following: "new", "open", "resolved",
"stalled", "rejected", and "deleted".  However, custom RT installations
sometimes add their own statuses.

=item B<priority>

Ticket priority.  Usually a numeric value.

=item B<initial_priority>

=item B<final_priority>

=item B<requestors>

This is a list attribute (for explanation of list attributes, see
B<LIST ATTRIBUTE PROPERTIES> in L<RT::Client::REST::Object>).  Contains
e-mail addresses of the requestors.

=item B<cc>

A list of e-mail addresses used to notify people of 'correspond'
actions.

=item B<admin_cc>

A list of e-mail addresses used to notify people of all actions performed
on a ticket.

=item B<created>

Time at which ticket was created.

=item B<starts>

=item B<started>

=item B<due>

=item B<resolved>

=item B<told>

=item B<time_estimated>

=item B<time_worked>

=item B<time_left>

=item B<last_updated>

=back

=head1 DB METHODS

For full explanation of these, please see B<"DB METHODS"> in
L<RT::Client::REST::Object> documentation.

=over 2

=item B<retrieve>

Retrieve RT ticket from database.

=item B<store ([text =E<gt> $text])>

Create or update the ticket.  When creating a new ticket, optional 'text'
parameter can be supplied to set the initial text of the ticket.

=item B<search>

Search for tickets that meet specific conditions.

=back

=head1 TICKET-SPECIFIC METHODS

=over 2

=item B<comment> (message => $message, %opts)

Comment on this ticket with message $message.  C<%opts> is a list of
key-value pairs as follows:

=over 2

=item B<attachments>

List of filenames (an array reference) that should be attached to the
ticket along with the comment.

=item B<cc>

List of e-mail addresses to send carbon copies to (an array reference).

=item B<bcc>

List of e-mail addresses to send blind carbon copies to (an array
reference).

=back

=item B<correspond> (message => $message, %opts)

Add correspondence to the ticket.  Takes exactly the same arguments
as the B<comment> method above.

=cut

# comment and correspond are really the same method, so we save ourselves
# some duplication here.
for my $method (qw(comment correspond)) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;

        if (@_ & 1) {
            RT::Client::REST::Object::OddNumberOfArgumentsException->throw;
        }

        $self->_assert_rt_and_id($method);

        my %opts = @_;

        unless (defined($opts{message})) {
            RT::Client::REST::Object::InvalidValueException->throw(
                "No message was provided",
            );
        }

        $self->rt->$method(
            ticket_id => $self->id,
            %opts,
        );

        return;
    };
}

=item B<attachments>

Get attachments associated with this ticket.  What is returned is an
object of type L<RT::Client::REST::SearchResult> which can then be used
to get at objects of type L<RT::Client::REST::Attachment>.

=cut

sub attachments {
    my $self = shift;
    
    $self->_assert_rt_and_id;

    RT::Client::REST::SearchResult->new(
        ids => [ $self->rt->get_attachment_ids(id => $self->id) ],
        object => sub {
            RT::Client::REST::Attachment->new(
                id => shift,
                parent_id => $self->id,
                rt => $self->rt,
            );
        },
    );
}

=item B<transactions>

Get transactions associated with this ticket.  Optionally, you can specify
exactly what types of transactions you want listed, for example:

  my $result = $ticket->transactions(type => [qw(Comment Correspond)]);

Please reference L<RT::Client::REST> documentation for the full list of
valid transaction types.

Return value is an object of type L<RT::Client::REST::SearchResult> which
can then be used to iterate over transaction objects
(L<RT::Client::REST::Transaction>).

=cut

sub transactions {
    my $self = shift;

    if (@_ & 1) {
        RT::Client::REST::Object::OddNumberOfArgumentsException->throw;
    }

    $self->_assert_rt_and_id;

    my %opts = @_;
    my %params = (
        parent_id => $self->id,
    );
    if (defined(my $type = delete($opts{type}))) {
        $params{transaction_type} = $type;
    }
    
    RT::Client::REST::SearchResult->new(
        ids => [ $self->rt->get_transaction_ids(%params) ],
        object => sub {
            RT::Client::REST::Transaction->new(
                id => shift,
                parent_id => $self->id,
                rt => $self->rt,
            );
        },
    );
}

=item B<take>

Take this ticket.
If you already the owner of this ticket,
C<RT::Client::REST::Object::NoopOperationException> will be thrown.

=item B<untake>

Untake this ticket.
If Nobody is already the owner of this ticket,
C<RT::Client::REST::Object::NoopOperationException> will be thrown.

=item B<steal>

Steal this ticket.
If you already the owner of this ticket,
C<RT::Client::REST::Object::NoopOperationException> will be thrown.

=cut

for my $method (qw(take untake steal)) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;

        $self->_assert_rt_and_id($method);

        try {
            $self->rt->$method(id => $self->id);
        } catch RT::Client::REST::AlreadyTicketOwnerException with {
            # Rename the exception.
            RT::Client::REST::Object::NoopOperationException
                ->throw(shift->message);
        };

        return;
    };
}

=back

=head1 INTERNAL METHODS

=over 2

=item B<rt_type>

Returns 'ticket'.

=cut

sub rt_type { 'ticket' }

=back

=head1 SEE ALSO

L<RT::Client::REST>, L<RT::Client::REST::Object>,
L<RT::Client::REST::Attachment>,
L<RT::Client::REST::SearchResult>,
L<RT::Client::REST::Transaction>.

=head1 AUTHOR

Dmitri Tikhonov <dtikhonov@yahoo.com>

=head1 LICENSE

Perl license with the exception of L<RT::Client::REST>, which is GPLed.

=cut

__PACKAGE__->_generate_methods;

1;