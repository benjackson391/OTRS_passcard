package Kernel::Language::ru_Passcard;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    $Self->{Translation}->{'Passcards'} = 'Пропуски';
    $Self->{Translation}->{'Passcard Management'} = 'Менеджер пропусков';
    $Self->{Translation}->{'Add passcard'} = 'Добавить пропуск';
    $Self->{Translation}->{'Filter for Passcards'} = 'Фильтр';
    $Self->{Translation}->{'Create a passcard to the users.'} = 'Создайте пропуск для пользователя';
    $Self->{Translation}->{'Create and manage passcards.'} = 'Управление пропусками';
    $Self->{Translation}->{'Valid Duration'} = 'Действителен до';
    $Self->{Translation}->{'Access JSON'} = 'json';
    $Self->{Translation}->{'Edit passcard'} = 'Редактировать пропуск';
    $Self->{Translation}->{'Passcard updated!'} = 'Пропуск обновлен';
    return 1;
}
1;