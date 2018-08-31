# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminPasscard;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $PasscardObject  = $Kernel::OM->Get('Kernel::System::Passcard');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Notification = $ParamObject->GetParam( Param => 'Notification' ) || '';
    $Self->{Config} = $ConfigObject->Get("Passcard::Map");

    if ( $Self->{Subaction} eq 'Change') {
        my $ID = $ParamObject->GetParam( Param => 'ID' )
            || $ParamObject->GetParam( Param => 'PasscardID' )
            || '';
        my %Data = $PasscardObject->PasscardGet( ID => $ID );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Info => Translatable('Passcard updated!') )
            if ( $Notification && $Notification eq 'Update' );

        $Self->_Edit(
            Action => 'Change',
            %Data,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPasscard',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
    elsif ($Self->{Subaction} eq 'ChangeAction') {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Parameter (qw(ID Customer ValidDuration ValidID)) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        $GetParam{AccessJSON} = join ',', $ParamObject->GetArray(Param => 'AccessJSON');

        # update Passcard
        my $PasscardUpdate = $PasscardObject->PasscardUpdate(
            %GetParam,
            UserID => $Self->{UserID}
        );

        if ($PasscardUpdate) {

            # if the user would like to continue editing the Passcard, just redirect to the edit screen
            if (
                defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
                    && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
            {
                my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';
                return $LayoutObject->Redirect(
                    OP => "Action=$Self->{Action};Subaction=Change;ID=$GetParam{ID};Notification=Update"
                );
            }
            else {

                # otherwise return to overview
                return $LayoutObject->Redirect( OP => "Action=$Self->{Action};Notification=Update" );
            }
        }
        else {
            $Note = $LogObject->GetLogEntry(
                Type => 'Error',
                What => 'Message',
            );
        }

        # something went wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note
            ? $LayoutObject->Notify(
            Priority => 'Error',
            Info     => $Note,
        )
            : '';
        $Self->_Edit(
            Action => 'Change',
            %GetParam,
            %Errors,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPasscard',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;

    }
    elsif ($Self->{Subaction} eq 'Add') {
        my %GetParam = ();

        $GetParam{Customer} = $ParamObject->GetParam( Param => 'Customer' );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Edit(
            Action => 'Add',
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPasscard',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
    elsif ($Self->{Subaction} eq 'AddAction') {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %GetParam;
        for my $Parameter (qw(Customer ValidDuration AccessJSON ValidID)) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # add Passcard
        my $PasscardID = $PasscardObject->PasscardAdd(
            %GetParam
        );

        if ($PasscardID) {
            return $LayoutObject->Redirect(
                OP => "Action=AdminPasscard",
            );
        }
    }
    else {
        $Self->_Overview();
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Info => Translatable('Passcard updated!') )
            if ( $Notification && $Notification eq 'Update' );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPasscard',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    $LayoutObject->Block(
    Name => 'Overview',
    Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );

    # get valid list
    my %ValidList        = $ValidObject->ValidList();
    my %ValidListReverse = reverse %ValidList;


    my $CustomerUserIDsRef = $CustomerUserObject->CustomerSearchDetail(
        UserLogin => '*',
    );

    my %CustomerList = map { $_ => $_ } @$CustomerUserIDsRef;

    use Data::Dumper;




    $Param{Customer} = $LayoutObject->BuildSelection(
        Data       => \%CustomerList,
        Name       => 'Customer',
        Class      => 'Modernize',
        SelectedID => $Param{Customer},
    );

    my $map;

    for my $floor (keys %{$Self->{Config}}) {
        for my $room ( @{${$Self->{Config}}{$floor}}) {
            $map->{$floor."::".$room} = $floor."::".$room;
        }
    }


    my %selected = map { $_ => $_ } split( ',', $Param{AccessJSON});
    my @selected = split( ',', $Param{AccessJSON});

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    $LogObject->Log(
        Priority => 'notice',
        Message  => '$$$$$$$$$$ ' . Dumper \@selected,
    );


    $Param{AccessJSON} = $LayoutObject->BuildSelection(
        Data       => $map,
        Name       => 'AccessJSON',
        Class      => 'Modernize W75pc',
        SelectedID => \@selected,
        Multiple   => 1,
        Size       => 8,
    );

    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        Class      => 'Modernize',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
    );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => \%Param,
    );

    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $PasscardObject  = $Kernel::OM->Get('Kernel::System::Passcard');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );

    my %List = $PasscardObject->PasscardList(
        ValidID => 0,
    );
    my $ListSize = keys %List;
    $Param{AllItemsCount} = $ListSize;

    $LayoutObject->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    # get valid list
    my %ValidList = $ValidObject->ValidList();
    for my $ListKey ( sort { $List{$a} cmp $List{$b} } keys %List ) {

        my %Data = $PasscardObject->PasscardGet(
            ID => $ListKey,
        );
        $LayoutObject->Block(
            Name => 'OverviewResultRow',
            Data => {
                Valid => $ValidList{ $Data{ValidID} },
                %Data,
            },
        );
    }
    return 1;
}

1;
