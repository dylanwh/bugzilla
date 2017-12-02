# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# This test combines two field/operator combinations using OR in
# a single boolean chart.
package Bugzilla::Test::Search::OrTest;
use parent qw(Bugzilla::Test::Search::FieldTest);

use Bugzilla::Test::Search::Constants;
use List::MoreUtils qw(all any uniq);

use constant type => 'OR';

###############
# Constructor #
###############

sub new {
    my $class = shift;
    my $self = { field_tests => [@_] };
    return bless $self, $class;
}

#############
# Accessors #
#############

sub field_tests { return @{ $_[0]->{field_tests} } }
sub search_test { ( $_[0]->field_tests )[0]->search_test }

sub name {
    my ($self) = @_;
    my @names = map { $_->name } $self->field_tests;
    return join( '-' . $self->type . '-', @names );
}

# In an OR test, bugs ARE supposed to be contained if they are contained
# by ANY test.
sub bug_is_contained {
    my ( $self, $number ) = @_;
    return any { $_->bug_is_contained($number) } $self->field_tests;
}

# Needed only for failure messages
sub debug_value {
    my ($self) = @_;
    my @values = map { $_->field . ' ' . $_->debug_value } $self->field_tests;
    return join( ' ' . $self->type . ' ', @values );
}

########################
# SKIP & TODO Messages #
########################

sub field_not_yet_implemented {
    my ($self) = @_;
    return $self->_join_messages('field_not_yet_implemented');
}

sub invalid_field_operator_combination {
    my ($self) = @_;
    return $self->_join_messages('invalid_field_operator_combination');
}

sub search_known_broken {
    my ($self) = @_;
    return $self->_join_messages('search_known_broken');
}

sub _join_messages {
    my ( $self, $message_method ) = @_;
    my @messages = map { $_->$message_method } $self->field_tests;
    @messages = grep {$_} @messages;
    return join( ' AND ', @messages );
}

sub _bug_will_actually_be_contained {
    my ( $self, $number ) = @_;

    foreach my $test ( $self->field_tests ) {

        # Some tests are broken in such a way that they actually
        # generate no criteria in the SQL. In this case, the only way
        # the test contains the bug is if *another* test contains it.
        next if $test->_known_broken->{no_criteria};
        return 1 if $test->will_actually_contain_bug($number);
    }
    return 0;
}

sub contains_known_broken {
    my ( $self, $number ) = @_;

    if (( $self->bug_is_contained($number) and !$self->_bug_will_actually_be_contained($number) )
        or (   !$self->bug_is_contained($number)
            and $self->_bug_will_actually_be_contained($number) )
        )
    {
        my @messages = map { $_->contains_known_broken($number) } $self->field_tests;
        @messages = grep {$_} @messages;

        # Sometimes, with things that break because of no_criteria, there won't
        # be anything in @messages even though we need to print out a message.
        if ( !@messages ) {
            my @no_criteria = grep { $_->_known_broken->{no_criteria} } $self->field_tests;
            @messages = map { "No criteria generated by " . $_->name } @no_criteria;
        }
        die "broken test with no message" if !@messages;
        return join( ' AND ', @messages );
    }
    return undef;
}

##############################
# Bugzilla::Search arguments #
##############################

sub search_columns {
    my ($self) = @_;
    my @columns = map { @{ $_->search_columns } } $self->field_tests;
    return [ uniq @columns ];
}

sub search_params {
    my ($self) = @_;
    my @all_params = map { $_->search_params } $self->field_tests;
    my %params;
    my $chart = 0;
    foreach my $item (@all_params) {
        $params{"field0-0-$chart"} = $item->{'field0-0-0'};
        $params{"type0-0-$chart"}  = $item->{'type0-0-0'};
        $params{"value0-0-$chart"} = $item->{'value0-0-0'};
        $chart++;
    }
    return \%params;
}

1;
