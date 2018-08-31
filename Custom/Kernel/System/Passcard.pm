# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Passcard;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub PasscardGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # get Passcard list
    my %PasscardList = $Self->PasscardDataList(
        Valid => 0,
    );

    # extract Passcard data
    my %Passcard;
    if ( $PasscardList{ $Param{ID} } && ref $PasscardList{ $Param{ID} } eq 'HASH' ) {
        %Passcard = %{ $PasscardList{ $Param{ID} } };
    }

    return %Passcard;
}

sub PasscardAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Customer ValidDuration AccessJSON ValidID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %ExistingPasscards = reverse $Self->PasscardList( Valid => 0 );
    if ( defined $ExistingPasscards{ $Param{Customer} } ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A Passcard for '$Param{Name}' already exists.",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO passcard (customer, valid_duration, access_json, valid_id) '
            . 'VALUES (?, ?, ?, ?)',
        Bind => [
            \$Param{Customer}, \$Param{ValidDuration}, \$Param{AccessJSON}, \$Param{ValidID}
        ],
    );

    my $PasscardID;
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM passcard WHERE customer = ?',
        Bind => [ \$Param{Customer}, ],
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $PasscardID = $Row[0];
    }

    return $PasscardID;
}

sub PasscardUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Customer ValidDuration AccessJSON ValidID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get current Passcard data
    my %PasscardData = $Self->PasscardGet(
        ID => $Param{ID},
    );

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (qw(Customer ValidDuration AccessJSON ValidID)) {
        next KEY if defined $PasscardData{$Key} && $PasscardData{$Key} eq $Param{$Key};
        $ChangeRequired = 1;
        last KEY;
    }

    return 1 if !$ChangeRequired;

    # update Passcard in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE passcard SET customer = ?, valid_duration = ?, access_json= ?, valid_id = ?'
            . 'WHERE id = ?',
        Bind => [
            \$Param{Customer}, \$Param{ValidDuration}, \$Param{AccessJSON}, \$Param{ValidID}, \$Param{ID}
        ],
    );

    return 1;
}

sub PasscardList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # get valid ids
    my @ValidIDs = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();

    # get Passcard data list
    my %PasscardDataList = $Self->PasscardDataList();

    my %PasscardListValid;
    my %PasscardListAll;
    KEY:
    for my $Key ( sort keys %PasscardDataList ) {

        next KEY if !$Key;

        # add Passcard to the list of all Passcards
        $PasscardListAll{$Key} = $PasscardDataList{$Key}->{Name};

        my $Match;
        VALIDID:
        for my $ValidID (@ValidIDs) {

            next VALIDID if $ValidID ne $PasscardDataList{$Key}->{ValidID};

            $Match = 1;

            last VALIDID;
        }

        next KEY if !$Match;

        # add Passcard to the list of valid Passcards
        $PasscardListValid{$Key} = $PasscardDataList{$Key}->{Name};
    }

    return %PasscardListValid if $Valid;
    return %PasscardListAll;
}

sub PasscardDataList {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get all Passcards data from database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, customer, valid_duration, access_json, valid_id FROM passcard',
    );

    # fetch the result
    my %PasscardDataList;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        $PasscardDataList{ $Row[0] } = {
            ID              => $Row[0],
            Customer        => $Row[1],
            ValidDuration   => $Row[2],
            AccessJSON      => $Row[3],
            ValidID         => $Row[4],
        };
    }

    return %PasscardDataList;
}

sub PasscardCheck {
    my ( $Self, %Param ) = @_;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    use Data::Dumper;
    $Kernel::OM->Get('Kernel::System::Log')->Log(
    Priority => 'error',
    Message  => Dumper \%Param
    );

    # get all Passcards data from database
    return if !$DBObject->Prepare(
    SQL  => 'SELECT id, customer, valid_duration, access_json, valid_id FROM passcard WHERE customer = ? LIMIT 1',
    Bind => => [\$Param{Customer}],
    );

    my @Row = $DBObject->FetchrowArray();

    my @access = split ',', $Row[3];
    for (@access) {
        my ($floor, $room) = split '::', $_;
        return 1 if ($Param{Floor} eq $floor and $Param{Room} eq $room);
    }
    return undef;
}

1;