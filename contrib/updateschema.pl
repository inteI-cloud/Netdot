#!/usr/bin/perl

use lib "/usr/local/netdot/lib";

use strict;
use DBI;
use Netdot::DBI;
use Data::Dumper;
use Getopt::Long;

use vars qw( %self $DBH $USAGE );

sub DEFAULT_DBDRIVER { "mysql" };
sub DEFAULT_DBNAME   { "netdot" };
sub DEFAULT_DBHOST   { "localhost" };
sub DEFAULT_DBUSER   { "root" };
sub DEFAULT_DBPASS   { "netdot_pass" };
sub DEFAULT_DATA     { "contrib/updateschema.data" };
sub DEFAULT_DBHOME   { "/usr" };

set_defaults();
my $USAGE = <<EOF;
usage: $0 [options]
          update schema for release of netdot

          --db  database driver to use (mysql, etc)
          -d <host> database host to connect to (default: $self{dbhost})
          -n <name> name of database (default: $self{dbname})
          -u <user> name of user to connect as (default: $self{dbuser})
          -p <pass> password of connecting user (default: $self{dbpass})
          -f <file> location of updateschema.data file
          -x <prefix> path to mysql installation (default: $self{dbhome})

          Meant to be run from top directory of source tree.

EOF

setup();
if( ! dbconnect() ) {
  die "Failed to connect to DB\n";
}
processdata();
dbdisconnect();
cleanup();

##################################################
sub set_defaults {
  %self = ( dbdriver => DEFAULT_DBDRIVER,
	    dbname => DEFAULT_DBNAME,
	    dbhost => DEFAULT_DBHOST,
	    dbuser => DEFAULT_DBUSER,
	    dbpass => DEFAULT_DBPASS,
	    data => DEFAULT_DATA,
	    dbhome => DEFAULT_DBHOME,
	    help => 0,
	    debug => 0 );
}


##################################################
sub setup {
  my $result = GetOptions( "v:i" => \$self{debug},
			   "h" => \$self{help},
			   "help" => \$self{help},
			   "f=s" => \$self{data},
			   "x=s" => \$self{dbhome},
			   "db=s" => \$self{dbdriver},
			   "n=s" => \$self{dbname},
			   "d=s" => \$self{dbhost},
			   "u=s" => \$self{dbuser},
			   "p=s" => \$self{dbpass} );
  if( $self{help} ) {
    print $USAGE;
    exit 0;
  }
  ################################################
  # now make sure we have what will be needed later
  foreach my $cmd ( ("Makefile", "bin/insert-metadata", "bin/setup-class-dbi") ) {
    if( ! -e $cmd ) {
      die "Error: missing required file $cmd\n";
    }
    if( ! -r $cmd ) {
      die "Error: can't read required file $cmd\n";
    }
  }
  ################################################
  # check for config file
  if( ! -e $self{data} || ! -r $self{data} ) {
    die "Error: Can't read data file $self{data}\n";
  }
  ################################################
  # check to make sure $self{dbhome} has a mysql binary
  if( ! -e "$self{dbhome}/bin/mysql" || ! -x "$self{dbhome}/bin/mysql" ) {
    die "Error: can't find mysql binary in $self{dbhome}.\n";
  }
  ################################################
  # keep password off screen
  print "Enter $self{dbdriver} password for $self{dbuser}: \n";
  system "stty -echo";
  $self{dbpass} = scalar(<STDIN>);
  system "stty echo";
  chomp( $self{dbpass} );
}


##################################################
sub dbconnect {
  my $s = "DBI:$self{dbdriver}:$self{dbname}:host=$self{dbhost}";
  if( $self{debug} ) {
    print "DEBUG: init: $s\n";
  }
  if( $DBH = DBI->connect( $s, $self{dbuser}, $self{dbpass} ) ) {
    return 1;
  } else {
    die "Unable to connect to $self{dbdriver} $self{dbname} db:" 
      . " $DBI::errstr\n"; 
  }
}


##################################################
sub dbdisconnect {
  if( $DBH->disconnect ) {
    return 1;
  } else {
    warn "Unable to disconnect from DB\n";
    return 0;
  }
}


##################################################
sub processdata {
  if( ! -e $self{data} ) {
    die "Can't find data file: $self{data} doesn't exist\n";
  }
  if( ! -r $self{data} ) {
    die "Can't read data file: $self{data}\n"; 
  }
  open( IN, $self{data} ) 
    or die "Unable to open $self{data}: $!\n";
  while( <IN> ) {
    ##############################################
    # rule of thumb processing this file:
    #   lines beginning with '#' are comments
    #   lines beginning with '#%' have shell commands to run
    next if( /^\s*$/o );
    next if( /^\#.*/o );
    chomp();

    if( /^\$/o ) {

      ############################################
      # this is a command to run
      my($cmd) = /^\$(.*)$/;
      if( $self{debug} > 1 ) {
	print "DEBUG: sys: $cmd\n";
      }
      print "Will run following command: '$cmd'\n";
      sleep 3;
      my $result = system( "$cmd" );
      if( $result ) {
	warn "Error running: $cmd\nReturned $result\n";
      }
    } else {

      ############################################
      # this is a sql command
      my($cmd) = /^(.*)$/;
      if( $self{debug} > 1 ) {
	print "DEBUG: cmd: $cmd\n";
      }
      my $rows = $DBH->do( $cmd );
      #$DBH->commit();
      if( $self{debug} ) {
	print "DEBUG: ($cmd): rows affected: $rows\n";
      }
    }
  }
  return 1;
}


##################################################
sub cleanup {
  if( ! -d "bin" || ! -e "bin/Makefile" 
      || ! -e "bin/insert-metadata" || ! -e "bin/setup-class-dbi" ) {
    print <<EOF;
File $self{data} has been processed.
You will need to run:
    insert-metadata
    setup-class-dbi
Afterward, you will have to copy DBI.pm to PREFIX/lib/Netdot.
These scripts can be found in the source directory (PREFIX/bin/).

You will also have to restart httpd.

EOF
  } else {
    system( "cd bin && make insert.metadata DB_HOME=$self{dbhome} && cd .." );
    system( "cd bin && make setup.class.dbi DB_HOME=$self{dbhome} && cd .." );
    print "Be sure to restart httpd after DBI.pm has been installed.\n";
  }
}