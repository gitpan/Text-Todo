#!/usr/bin/perl
# $RedRiver: todo.pl,v 1.13 2010/01/11 02:35:39 andrew Exp $
########################################################################
# todo.pl *** a perl version of todo.sh. Uses Text::Todo.
#
# 2010.01.07 #*#*# andrew fresh <andrew@cpan.org>
########################################################################
# Copyright 2010 Andrew Fresh, all rights reserved
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
########################################################################
use strict;
use warnings;

use Data::Dumper;

use Getopt::Std;
use Text::Todo;

use version; our $VERSION = qv('0.0.1');

# option defaults
my $config_file = $ENV{HOME} . '/todo.cfg';
CONFIG: foreach my $f ( $config_file, $ENV{HOME} . '/.todo.cfg', ) {
    if ( -e $f ) {
        $config_file = $f;
        last CONFIG;
    }
}

my %actions = (
    add      => \&add,
    addto    => \&addto,
    append   => \&append,
    archive  => \&archive,
    command  => \&command,
    del      => \&del,
    depri    => \&depri,
    do       => \&mark_done,
    help     => \&help,
    list     => \&list,
    listall  => \&listall,
    listcon  => \&listcon,
    listfile => \&listfile,
    listpri  => \&listpri,
    listproj => \&listproj,
    move     => \&move,
    prepend  => \&prepend,
    pri      => \&pri,
    replace  => \&replace,
    report   => \&report,
);

my %aliases = (
    a     => 'add',
    app   => 'append',
    rm    => 'del',
    dp    => 'depri',
    ls    => 'list',
    lsa   => 'listall',
    lsc   => 'listcon',
    lf    => 'listfile',
    lsp   => 'listpri',
    lsprj => 'listproj',
    mv    => 'move',
    prep  => 'prepend',
    p     => 'pri',
);

my %opts;
getopts( '@+d:fhpPntvV', \%opts );

my $action = shift @ARGV;
if ( $action && $action eq 'command' ) {

    # We don't support action scripts so . . .
    $action = shift @ARGV;
}
if ( $action && exists $aliases{$action} ) {
    $action = $aliases{$action};
}

if ( $opts{h} || !$action ) {
    usage( $opts{h} );
}

my @unsupported = grep { defined $opts{$_} } qw( @ + f h p P t v V );
if (@unsupported) {
    warn 'Unsupported options: ' . ( join q{, }, @unsupported ) . "\n";
}

if ( $opts{d} ) {
    $config_file = $opts{d};
}

if ( exists $actions{$action} ) {
    my $config = read_config($config_file);
    my $action = $actions{$action}->( $config, @ARGV );
}
else {
    usage();
}

sub add {
    my ( $config, @entry ) = @_;
    if ( !@entry ) {
        die "usage: todo.pl add 'item'\n";
    }

    my $entry = join q{ }, @entry;

    my $todo = Text::Todo->new($config);
    if ( $todo->add($entry) ) {
        my @list  = $todo->list;
        my $lines = scalar @list;

        print "TODO: '$entry' added on line $lines\n";

        return $lines;
    }
    die "Unable to add [$entry]\n";
}

sub addto {
    my ( $config, $file, @entry ) = @_;
    if ( !( $file && @entry ) ) {
        die "usage: todo.pl addto DEST 'TODO ITEM'\n";
    }

    my $entry = join q{ }, @entry;

    my $todo = Text::Todo->new($config);

    $file = $todo->file($file);
    if ( $todo->addto( $file, $entry ) ) {
        my @list  = $todo->listfile($file);
        my $lines = scalar @list;

        print "TODO: '$entry' added to $file on line $lines\n";

        return $lines;
    }
    die "Unable to add [$entry]\n";
}

sub append {
    my ( $config, $line, @text ) = @_;
    if ( !( $line && @text && $line =~ /^\d+$/xms ) ) {
        die 'usage: todo.pl append ITEM# "TEXT TO APPEND"' . "\n";
    }

    my $text = join q{ }, @text;

    my $todo  = Text::Todo->new($config);
    my $entry = $todo->list->[ $line - 1 ];

    if ( $entry->append($text) && $todo->save ) {
        return printf "%02d: %s\n", $line, $entry->text;
    }
    die "Unable to append\n";
}

sub archive {
    my ($config) = @_;
    my $todo = Text::Todo->new($config);

    my $file = $todo->file;

    my $archived = $todo->archive;
    if ( defined $archived ) {
        return print "TODO: $file archived.\n";
    }
    die "Unable to archive $file\n";
}

sub command { return &unsupported }

sub del {
    my ( $config, $line ) = @_;
    if ( !( $line && $line =~ /^\d+$/xms ) ) {
        die 'usage: todo.pl del ITEM#' . "\n";
    }
    my $todo = Text::Todo->new($config);

    my $entry = $todo->list->[ $line - 1 ];
    print "Delete '" . $entry->text . "'?  (y/n)\n";
    warn "XXX No delete confirmation currently!\n";

    if ( $opts{n} ) {
        if ( $todo->del($entry) && $todo->save ) {
            return print 'TODO: \'', $entry->text, "' deleted.\n";
        }
    }
    else {
        my $text = $entry->text;
        if ( $entry->replace(q{}) && $todo->save ) {
            return print 'TODO: \'', $text, "' deleted.\n";
        }
    }

    die "Unable to delete entry\n";
}

sub depri {
    my ( $config, $line ) = @_;
    if ( !( $line && $line =~ /^\d+$/xms ) ) {
        die 'usage: todo.pl depri ITEM#' . "\n";
    }
    my $todo = Text::Todo->new($config);

    my $entry = $todo->list->[ $line - 1 ];
    if ( $entry->depri && $todo->save ) {
        return print $line, ': ', $entry->text, "\n",
            'TODO: ', $line, " deprioritized.\n";
    }
    die "Unable to deprioritize entry\n";
}

# since "do" is reserved
sub mark_done { 
    my ( $config, $line ) = @_;
    if ( !( $line && $line =~ /^\d+$/xms ) ) {
        die 'usage: todo.pl del ITEM#' . "\n";
    }
    my $todo = Text::Todo->new($config);

    my $entry = $todo->list->[ $line - 1 ];

    if ( $entry->do && $todo->save ) {
        my $status = print $line, ': ', $entry->text, "\n",
            'TODO: ', $line, " marked as done.\n";
        if (!$opts{a}) {
            return archive($config);
        }
        return $status;
    }
    die "Unable to mark as done\n";
}

sub help      { return &unsupported }

sub list {
    my ( $config, $term ) = @_;
    my $todo = Text::Todo->new($config);

    my @list = _number_list( $todo->list );
    my $shown = _show_sorted_list( $term, @list );

    return _show_list_footer( $shown, scalar @list, $config->{todo_file} );
}

sub listall {
    my ( $config, $term ) = @_;
    my $todo = Text::Todo->new($config);

    my @list = _number_list(
        $todo->listfile('todo_file'),
        $todo->listfile('done_file'),
    );
    my $shown = _show_sorted_list( $term, @list );

    return _show_list_footer( $shown, scalar @list, $config->{'todo_dir'} );
}

sub listcon {
    my ($config) = @_;
    my $todo = Text::Todo->new($config);
    return print map {"\@$_\n"} $todo->listcon;
}

sub listfile {
    my ( $config, $file, $term ) = @_;
    if ( !$file ) {
        die "usage: todo.pl listfile SRC [TERM]\n";
    }
    my $todo = Text::Todo->new($config);

    my @list = _number_list( $todo->listfile($file) );
    my $shown = _show_sorted_list( $term, @list );

    return _show_list_footer( $shown, scalar @list, $file );
}

sub listpri {
    my ( $config, $pri ) = @_;

    my $todo = Text::Todo->new($config);

    my @list = _number_list( $todo->listfile('todo_file') );
    my @pri_list;
    if ($pri) {
        $pri = uc $pri;
        if ( $pri !~ /^[A-Z]$/xms ) {
            die "usage: todo.pl listpri PRIORITY\n",
                "note: PRIORITY must a single letter from A to Z.\n";
        }
        @pri_list = grep {
            defined $_->{entry}->priority
                && $_->{entry}->priority eq $pri
        } @list;
    }
    else {
        @pri_list = grep { $_->{entry}->priority } @list;
    }

    my $shown = _show_sorted_list( undef, @pri_list );

    return _show_list_footer( $shown, scalar @list, $config->{todo_file} );
}

sub listproj {
    my ($config) = @_;
    my $todo = Text::Todo->new($config);
    return print map {"\+$_\n"} $todo->listproj;
}

sub move { return &unsupported }

sub prepend {
    my ( $config, $line, @text ) = @_;
    if ( !( $line && @text && $line =~ /^\d+$/xms ) ) {
        die 'usage: todo.pl prepend ITEM# "TEXT TO PREPEND"' . "\n";
    }

    my $text = join q{ }, @text;

    my $todo  = Text::Todo->new($config);
    my $entry = $todo->list->[ $line - 1 ];

    if ( $entry->prepend($text) && $todo->save ) {
        return printf "%02d: %s\n", $line, $entry->text;
    }
    die "Unable to prepend\n";
}

sub pri {
    my ( $config, $line, $priority ) = @_;
    my $error = 'usage: todo.pl pri ITEM# PRIORITY';
    if ( !( $line && $line =~ /^\d+$/xms && $priority ) ) {
        die $error;
    }
    if ( $priority !~ /^[A-Z]$/xms ) {
        die $error . "\n"
            . "note: PRIORITY must a single letter from A to Z.\n";
    }

    my $todo = Text::Todo->new($config);

    my $entry = $todo->list->[ $line - 1 ];
    if ( $entry->pri($priority) && $todo->save ) {
        return print $line, ': ', $entry->text, "\n",
            'TODO: ', $line, ' prioritized (', $entry->priority, ").\n";
    }
    die "Unable to prioritize entry\n";
}

sub replace { return &unsupported }
sub report  { return &unsupported }

sub _number_list {
    my (@list) = @_;

    my $line = 1;
    return map { { line => $line++, entry => $_, } } @list;
}

sub _show_sorted_list {
    my ( $term, @list ) = @_;
    $term = defined $term ? quotemeta($term) : '';

    my $shown = 0;
    my @sorted = map { sprintf "%02d %s", $_->{line}, $_->{entry}->text }
        sort { lc $a->{entry}->text cmp lc $b->{entry}->text } @list;

    foreach my $line ( grep {/$term/xms} @sorted ) {
        print $line, "\n";
        $shown++;
    }

    return $shown;
}

sub _show_list_footer {
    my ( $shown, $total, $file ) = @_;

    $shown ||= 0;
    $total ||= 0;

    print "-- \n";
    print "TODO: $shown of $total tasks shown from $file\n";

    return 1;
}

sub unsupported { die "Unsupported action\n" }

sub usage {
    my ($long) = @_;

    print <<'EOL';
  * command list taken from todo.sh for compatibility
  Usage: todo.pl [-fhpantvV] [-d todo_config] action
EOL

    if ($long) {
        print <<'EOL';

  Actions:
    add|a "THING I NEED TO DO +project @context"
    addto DEST "TEXT TO ADD"
    append|app NUMBER "TEXT TO APPEND"
    archive
    command [ACTIONS]
    del|rm NUMBER [TERM]
    dp|depri NUMBER
    do NUMBER
    help
    list|ls [TERM...]
    listall|lsa [TERM...]
    listcon|lsc
    listfile|lf SRC [TERM...]
    listpri|lsp [PRIORITY]
    listproj|lsprj
    move|mv NUMBER DEST [SRC]
    prepend|prep NUMBER "TEXT TO PREPEND"
    pri|p NUMBER PRIORITY
    replace NUMBER "UPDATED TODO"
    report
EOL
    }
    else {
        print <<'EOL';
Try 'todo.pl -h' for more information.
EOL
    }

    exit;
}

sub read_config {
    my ($file) = @_;

    my %config;
    open my $fh, '<', $file or die "Unable to open [$file] : $!";
LINE: while (<$fh>) {
        s/\r?\n$//xms;
        s/\s*\#.*$//xms;
        next LINE unless $_;

        if (s/^\s*export\s+//xms) {
            my ( $key, $value ) = /^([^=]+)\s*=\s*"?(.*?)"?\s*$/xms;
            if ($key) {
                foreach my $k ( keys %config ) {
                    $value =~ s/\$\Q$k\E/$config{$k}/gxms;
                    $value =~ s/\${\Q$k\E}/$config{$k}/gxms;
                }
                foreach my $k ( keys %ENV ) {
                    $value =~ s/\$\Q$k\E/$ENV{$k}/gxms;
                    $value =~ s/\${\Q$k\E}/$ENV{$k}/gxms;
                }
                $value =~ s/\$\w+//gxms;
                $value =~ s/\${\w+}//gxms;

                $config{$key} = $value;
            }
        }
    }
    close $fh;

    my %lc_config;
    foreach my $k ( keys %config ) {
        $lc_config{ lc($k) } = $config{$k};
    }

    return \%lc_config;
}

__END__

=head1 NAME

todo.pl - a perl replacement for todo.sh


=head1 VERSION

Since the $VERSION can't be automatically included, 
here is the RCS Id instead, you'll have to look up $VERSION.

    $Id: todo.pl,v 1.13 2010/01/11 02:35:39 andrew Exp $


=head1 SYNOPSIS

    todo.pl list

    todo.pl -h

=head1 DESCRIPTION

Mostly compatible with todo.sh but not completely.
Any differences are either noted under limitations is a bug.

This is a proof of concept to get the Text::Todo modules used. 

The modules are there to give more access to my todo.txt file from more
places.  My goal is a web API for a web interface and then a WebOS version for
my Palm Pre.

For more information see L<http://todotxt.com>


=head1 CONFIGURATION AND ENVIRONMENT

todo.pl should read the todo.cfg file that todo.sh uses.  It is a very
simplistic reader and would probably be easy to break.

It only uses TODO_DIR, TODO_FILE and DONE_DIR

It does not currently support any of the environment variables that todo.sh
uses.


=head1 DEPENDENCIES 

Perl Modules:

=over

=item Text::Todo

=item version

=back


=head1 INCOMPATIBILITIES

Text::Todo::Entry actually checks if the entry is done before marking it
complete again.

Text::Todo::Entry will keep the completed marker and then the priority at the
beginning of the line in that order.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Known limitations:

Does not support some command line arguments. 
    @, +, f, h, p, P, t, v or V.

Does not yet support some actions.  Specifically, command, help and report. 

Does not colorize output.


=head1 AUTHOR

Andrew Fresh  C<< <andrew@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Andrew Fresh C<< <andrew@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
