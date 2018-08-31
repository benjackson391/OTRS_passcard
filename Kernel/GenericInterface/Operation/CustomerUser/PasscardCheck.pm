# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::CustomerUser::PasscardCheck;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::Ticket::Common
);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        return $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    return $Self->ReturnError(
        ErrorCode    => 'PasscardCheck.AuthFail',
        ErrorMessage => "PasscardCheck: Authorization failing!",
    ) if !$UserID;

    # check needed stuff
    for my $Needed (qw(customer_id floor room)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'PasscardCheck.MissingParameter',
                ErrorMessage => "PasscardCheck: $Needed parameter is missing!",
            );
        }
    }

    my $PasscardObject = $Kernel::OM->Get('Kernel::System::Passcard');

    my $Passcard = $PasscardObject->PasscardCheck(
        Customer => $Param{Data}->{customer_id},
        Floor => $Param{Data}->{floor},
        Room => $Param{Data}->{room},
    );

    my $ReturnData = {
        Success => 1,
    };

    $ReturnData->{Data}->{Access} = ($Passcard) ? 'true' : 'false';

    return $ReturnData;
    # my $ErrorMessage = '';
    #
    # # all needed variables
    # my @TicketIDs;
    # if ( IsStringWithData( $Param{Data}->{TicketID} ) ) {
    #     @TicketIDs = split( /,/, $Param{Data}->{TicketID} );
    # }
    # elsif ( IsArrayRefWithData( $Param{Data}->{TicketID} ) ) {
    #     @TicketIDs = @{ $Param{Data}->{TicketID} };
    # }
    # else {
    #     return $Self->ReturnError(
    #         ErrorCode    => 'PasscardCheck.WrongStructure',
    #         ErrorMessage => "PasscardCheck: Structure for TicketID is not correct!",
    #     );
    # }
    #
    # # Get the list of article dynamic fields
    # my $ArticleDynamicFieldList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
    #     ObjectType => 'Article',
    #     ResultType => 'HASH',
    # );
    #
    # # Crate a lookup list for easy search
    # my %ArticleDynamicFieldLookup = reverse %{$ArticleDynamicFieldList};
    #
    # TICKET:
    # for my $TicketID (@TicketIDs) {
    #
    #     my $Access = $Self->CheckAccessPermissions(
    #         TicketID => $TicketID,
    #         UserID   => $UserID,
    #         UserType => $UserType,
    #     );
    #
    #     next TICKET if $Access;
    #
    #     return $Self->ReturnError(
    #         ErrorCode    => 'PasscardCheck.AccessDenied',
    #         ErrorMessage => 'PasscardCheck: User does not have access to the ticket!',
    #     );
    # }
    #
    # my $DynamicFields = $Param{Data}->{DynamicFields} || 0;
    # my $Extended      = $Param{Data}->{Extended}      || 0;
    # my $AllArticles   = $Param{Data}->{AllArticles}   || 0;
    # my $ArticleOrder  = $Param{Data}->{ArticleOrder}  || 'ASC';
    # my $ArticleLimit  = $Param{Data}->{ArticleLimit}  || 0;
    # my $Attachments   = $Param{Data}->{Attachments}   || 0;
    # my $GetAttachmentContents = $Param{Data}->{GetAttachmentContents} // 1;
    #
    # my $ReturnData = {
    #     Success => 1,
    # };
    # my @Item;
    #
    # my $ArticleSenderType = '';
    # if ( IsArrayRefWithData( $Param{Data}->{ArticleSenderType} ) ) {
    #     $ArticleSenderType = $Param{Data}->{ArticleSenderType};
    # }
    # elsif ( IsStringWithData( $Param{Data}->{ArticleSenderType} ) ) {
    #     $ArticleSenderType = [ $Param{Data}->{ArticleSenderType} ];
    # }
    #
    # # By default, do not include HTML body as attachment, unless it is explicitly requested.
    # my %ExcludeAttachments = (
    #     ExcludePlainText => 1,
    #     ExcludeHTMLBody  => $Param{Data}->{HTMLBodyAsAttachment} ? 0 : 1,
    # );
    #
    # # start ticket loop
    # TICKET:
    # for my $TicketID (@TicketIDs) {
    #
    #     my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    #
    #     # get the Ticket entry
    #     my %TicketEntryRaw = $TicketObject->PasscardCheck(
    #         TicketID      => $TicketID,
    #         DynamicFields => $DynamicFields,
    #         Extended      => $Extended,
    #         UserID        => $UserID,
    #     );
    #
    #     if ( !IsHashRefWithData( \%TicketEntryRaw ) ) {
    #
    #         $ErrorMessage = 'Could not get Ticket data'
    #             . ' in Kernel::GenericInterface::Operation::Ticket::PasscardCheck::Run()';
    #
    #         return $Self->ReturnError(
    #             ErrorCode    => 'PasscardCheck.NotValidTicketID',
    #             ErrorMessage => "PasscardCheck: $ErrorMessage",
    #         );
    #     }
    #
    #     my %TicketEntry;
    #     my @DynamicFields;
    #
    #     # remove all dynamic fields from main ticket hash and set them into an array.
    #     ATTRIBUTE:
    #     for my $Attribute ( sort keys %TicketEntryRaw ) {
    #
    #         if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
    #             push @DynamicFields, {
    #                 Name  => $1,
    #                 Value => $TicketEntryRaw{$Attribute},
    #             };
    #             next ATTRIBUTE;
    #         }
    #
    #         $TicketEntry{$Attribute} = $TicketEntryRaw{$Attribute};
    #     }
    #
    #     $TicketEntry{TimeUnit} = $TicketObject->TicketAccountedTimeGet(
    #         TicketID => $TicketID,
    #     );
    #
    #     # add dynamic fields array into 'DynamicField' hash key if any
    #     if (@DynamicFields) {
    #         $TicketEntry{DynamicField} = \@DynamicFields;
    #     }
    #
    #     # set Ticket entry data
    #     my $TicketBundle = {
    #         %TicketEntry,
    #     };
    #
    #     if ( !$AllArticles ) {
    #         push @Item, $TicketBundle;
    #         next TICKET;
    #     }
    #
    #     my %ArticleListFilters;
    #     if ( $UserType eq 'Customer' ) {
    #         %ArticleListFilters = (
    #             IsVisibleForCustomer => 1,
    #         );
    #     }
    #
    #     my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    #
    #     my @Articles;
    #     if ($ArticleSenderType) {
    #         for my $SenderType ( @{ $ArticleSenderType || [] } ) {
    #             my @ArticlesFiltered = $ArticleObject->ArticleList(
    #                 TicketID   => $TicketID,
    #                 SenderType => $SenderType,
    #                 %ArticleListFilters,
    #             );
    #             push @Articles, @ArticlesFiltered;
    #         }
    #     }
    #     else {
    #         @Articles = $ArticleObject->ArticleList(
    #             TicketID => $TicketID,
    #             %ArticleListFilters,
    #         );
    #     }
    #
    #     # Set number of articles by ArticleLimit and ArticleOrder parameters.
    #     if ( IsArrayRefWithData( \@Articles ) && $ArticleLimit ) {
    #         if ( $ArticleOrder eq 'DESC' ) {
    #             @Articles = reverse @Articles;
    #         }
    #         @Articles = @Articles[ 0 .. ( $ArticleLimit - 1 ) ];
    #     }
    #
    #     # start article loop
    #     ARTICLE:
    #     for my $Article (@Articles) {
    #
    #         my $ArticleBackendObject = $ArticleObject->BackendForArticle( %{$Article} );
    #
    #         my %ArticleData = $ArticleBackendObject->ArticleGet(
    #             TicketID      => $TicketID,
    #             ArticleID     => $Article->{ArticleID},
    #             DynamicFields => $DynamicFields,
    #         );
    #         $Article = \%ArticleData;
    #
    #         next ARTICLE if !$Attachments;
    #
    #         # get attachment index (without attachments)
    #         my %AtmIndex = $ArticleBackendObject->ArticleAttachmentIndex(
    #             ArticleID => $Article->{ArticleID},
    #             %ExcludeAttachments,
    #         );
    #
    #         next ARTICLE if !IsHashRefWithData( \%AtmIndex );
    #
    #         my @Attachments;
    #         ATTACHMENT:
    #         for my $FileID ( sort keys %AtmIndex ) {
    #             next ATTACHMENT if !$FileID;
    #             my %Attachment = $ArticleBackendObject->ArticleAttachment(
    #                 ArticleID => $Article->{ArticleID},
    #                 FileID    => $FileID,                 # as returned by ArticleAttachmentIndex
    #             );
    #
    #             next ATTACHMENT if !IsHashRefWithData( \%Attachment );
    #
    #             $Attachment{FileID} = $FileID;
    #             if ($GetAttachmentContents)
    #             {
    #                 # convert content to base64
    #                 $Attachment{Content} = encode_base64( $Attachment{Content} );
    #             }
    #             else {
    #                 # unset content
    #                 $Attachment{Content}            = '';
    #                 $Attachment{ContentAlternative} = '';
    #             }
    #             push @Attachments, {%Attachment};
    #         }
    #
    #         # set Attachments data
    #         $Article->{Attachment} = \@Attachments;
    #
    #     }    # finish article loop
    #
    #     # set Ticket entry data
    #     if (@Articles) {
    #
    #         my @ArticleBox;
    #
    #         for my $ArticleRaw (@Articles) {
    #             my %Article;
    #             my @ArticleDynamicFields;
    #
    #             # remove all dynamic fields from main article hash and set them into an array.
    #             ATTRIBUTE:
    #             for my $Attribute ( sort keys %{$ArticleRaw} ) {
    #
    #                 if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
    #
    #                     # skip dynamic fields that are not article related
    #                     # this is needed because ArticleGet() also returns ticket dynamic fields
    #                     next ATTRIBUTE if ( !$ArticleDynamicFieldLookup{$1} );
    #
    #                     push @ArticleDynamicFields, {
    #                         Name  => $1,
    #                         Value => $ArticleRaw->{$Attribute},
    #                     };
    #                     next ATTRIBUTE;
    #                 }
    #
    #                 $Article{$Attribute} = $ArticleRaw->{$Attribute};
    #             }
    #
    #             $Article{TimeUnit} = $ArticleObject->ArticleAccountedTimeGet(
    #                 ArticleID => $ArticleRaw->{ArticleID}
    #             );
    #
    #             # add dynamic fields array into 'DynamicField' hash key if any
    #             if (@ArticleDynamicFields) {
    #                 $Article{DynamicField} = \@ArticleDynamicFields;
    #             }
    #
    #             push @ArticleBox, \%Article;
    #         }
    #         $TicketBundle->{Article} = \@ArticleBox;
    #     }
    #
    #     # add
    #     push @Item, $TicketBundle;
    # }    # finish ticket loop
    #
    # if ( !scalar @Item ) {
    #     $ErrorMessage = 'Could not get Ticket data'
    #         . ' in Kernel::GenericInterface::Operation::Ticket::PasscardCheck::Run()';
    #
    #     return $Self->ReturnError(
    #         ErrorCode    => 'PasscardCheck.NotTicketData',
    #         ErrorMessage => "PasscardCheck: $ErrorMessage",
    #     );
    #
    # }
    #
    # # set ticket data into return structure
    # $ReturnData->{Data}->{Ticket} = \@Item;
    #
    # # return result
    # return $ReturnData;
}

1;
