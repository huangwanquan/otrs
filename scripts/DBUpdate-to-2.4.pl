#!/usr/bin/perl -w
# --
# DBUpdate-to-2.4.pl - update script to migrate OTRS 2.3.x to 2.4.x
# Copyright (C) 2001-2009 OTRS AG, http://otrs.org/
# --
# $Id: DBUpdate-to-2.4.pl,v 1.1 2009-04-27 11:28:51 mh Exp $
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';

use vars qw($VERSION);
$VERSION = qw($Revision: 1.1 $) [1];

use Getopt::Std;
use Kernel::Config;
use Kernel::System::CheckItem;
use Kernel::System::Log;
use Kernel::System::Time;
use Kernel::System::Encode;
use Kernel::System::DB;
use Kernel::System::Main;
use Kernel::System::Config;
use Kernel::System::Ticket;

# get options
my %Opts;
getopt( 'h', \%Opts );
if ( $Opts{'h'} ) {
    print STDOUT "DBUpdate-to-2.4.pl <Revision $VERSION> - Database migration script\n";
    print STDOUT "Copyright (C) 2001-2009 OTRS AG, http://otrs.org/\n";
    exit 1;
}

print STDOUT "Start migration of the system...\n\n";

# create needed objects
my %CommonObject;
$CommonObject{ConfigObject} = Kernel::Config->new();
$CommonObject{LogObject}    = Kernel::System::Log->new(
    LogPrefix => 'OTRS-DBUpdate-to-2.4',
    %CommonObject,
);
$CommonObject{EncodeObject}    = Kernel::System::Encode->new(%CommonObject);
$CommonObject{MainObject}      = Kernel::System::Main->new(%CommonObject);
$CommonObject{TimeObject}      = Kernel::System::Time->new(%CommonObject);
$CommonObject{DBObject}        = Kernel::System::DB->new(%CommonObject);
$CommonObject{SysConfigObject} = Kernel::System::Config->new(%CommonObject);

# define config dir
my $ConfigDir = $CommonObject{ConfigObject}->Get('Home') . '/Kernel/Config/Files/';

# check ZZZ files
my %ZZZFiles = (
    ZZZAAuto => -f $ConfigDir . 'ZZZAAuto.pm' ? 1 : 0,
    ZZZAuto  => -f $ConfigDir . 'ZZZAuto.pm'  ? 1 : 0,
);

# rebuild config
my $Success = RebuildConfig();

# error handling
if ( !$Success ) {
    print STDOUT "Can't write config files! Please run the SetPermissions.sh and try it again.";
    exit 0;
}

# instance needed objects
$CommonObject{ConfigObject} = Kernel::Config->new();

# start migration process
CleanUpCacheDir();

# removed ZZZ files to fix permission problem
ZZZFILE:
for my $ZZZFile ( keys %ZZZFiles ) {
    next ZZZFILE if $ZZZFiles{$ZZZFile};
    unlink $ConfigDir . $ZZZFile . '.pm';
}

print STDOUT "\nMigration of the system completed!\n";

exit 0;

=item RebuildConfig()

rebuild config files (based on Kernel/Config/Files/*.xml)

    RebuildConfig();

=cut

sub RebuildConfig {

    print STDOUT "NOTICE: Rebuild config... ";

    my $Success = $CommonObject{SysConfigObject}->WriteDefault();

    if ( !$Success ) {
        print STDOUT " failed.\n";
        return;
    }

    print STDOUT " done.\n";

    return 1;
}

=item CleanUpCacheDir()

this function removes all cache files

    CleanUpCacheDir();

=cut

sub CleanUpCacheDir {

    print STDOUT "NOTICE: Clean up old cache files... ";

    my $CacheDirectory = $CommonObject{ConfigObject}->Get('TempDir');

    # delete all cache files
    my @CacheFiles = glob( $CacheDirectory . '/*' );
    for my $CacheFile (@CacheFiles) {
        next if ( !-f $CacheFile );
        unlink $CacheFile;
    }
    print STDOUT " done.\n";

    return 1;
}

1;
