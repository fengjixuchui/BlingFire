@perl -Sx %0 %*
@goto :eof
#!perl

use File::Temp qw/ :mktemp  /;

sub usage {

print <<EOM;

Usage: fa_build_dict_fst [OPTIONS]

From the input stream of "W1\\tW2\\n" lines, this program creates a data
structure that maps for every input W1 it returns all associated W2.
The input should be in UTF-8.

  --in=<input> - input file name, stdin is used if omited

  --out-fsm=<output-file> - output FSM file,
    if omited stdout is used

  --out-ows=<output-file> - output map of output-weights,
    if omited stdout is used

  --ignore-case - converts input symbols to the lower case,
    uses simple case folding algorithm due to Unicode 4.1.0

  --charmap=<mmap-dump> - applies a custom character normalization procedure
    according to the <mmap-dump>, the dump should be in "fixed" format

  --remove-equal - if specified, removes W1 == W2 pairs (words are compared 
    after normalization)

EXTRA PARAMETERS:

  Takes all fa_align parameters, see "fa_align --help" for details.

EOM

}

$input = "" ;
$out_fsm = "" ;
$out_ows = "" ;
$ignore_case = "" ;
$align_paramters = "" ;
$remove_equal = "" ;

while (0 < 1 + $#ARGV) {

    if("--help" eq $ARGV [0]) {

        usage ();
        exit (0);

    } elsif ($ARGV [0] =~ /^--in=(.+)/) {

        $input = $1;

    } elsif ($ARGV [0] =~ /^--out-fsm=(.+)/) {

        $out_fsm = $1;

    } elsif ($ARGV [0] =~ /^--out-ows=(.+)/) {

        $out_ows = $1;

    } elsif ("--ignore-case" eq $ARGV [0]) {

        $ignore_case .= (" " . $ARGV [0]);

    } elsif ($ARGV [0] =~ /^--charmap=./) {

        $ignore_case .= (" " . $ARGV [0]);

    } elsif ("--remove-equal" eq $ARGV [0]) {

        $remove_equal .= (" " . $ARGV [0]);

    } elsif ($ARGV [0] =~ /^--rev/ ||
             $ARGV [0] =~ /^--filler=./ ||
             $ARGV [0] =~ /^--no-epsilon/ ||
             $ARGV [0] =~ /^--filler2=./ ||
             $ARGV [0] =~ /^--gap1=./ ||
             $ARGV [0] =~ /^--gap2=./ ||
             $ARGV [0] =~ /^--not-equal=./ ||
             $ARGV [0] =~ /^--not-equal2=./ ||
             $ARGV [0] =~ /^--equal2=./ ||
             $ARGV [0] =~ /^--min-len=./) {

        $align_paramters = ($align_paramters . " " . $ARGV [0]);

    } elsif ($ARGV [0] =~ /^-.*/) {

        print STDERR "ERROR: Unknown parameter $$ARGV[0], see fa_build_dict_fst --help";
        exit (1);

    } else {

        last;
    }
    shift @ARGV;
}


$SIG{PIPE} = sub { die "ERROR: Broken pipe at fa_build_dict_fst" };


#
# Removes duplicates
#

$rm_dup = <<'EOF';

$[ = 1;			# set array base to 1
$\ = "\n";		# set output record separator
$FS = "\t";

while (<STDIN>) {

    s/[\r\n]+$//;
    s/^\xEF\xBB\xBF//;

    @Fld = split($FS, $_, 9999);

    if ($Fld[1] ne $Fld[2]) {
        print $Fld[1] . "\t" . $Fld[2] ;
    }
}

EOF

($fh, $rm_dup_tmp1) = mkstemp ("fa_build_dict_fst_XXXXXXXX");
print $fh $rm_dup;
close $fh;



#
# 1. read input file / stdin
# 2. apply character normalization
# 3. if $remove_equal specified, remove pairs W1 == W2
# 4. align each W1 and W2 words
# 5. digitalize aligned sequences and store Ows map
# 6. sort
# 7. make minimal DFA over the <Iw:Ow> 
#

$command = "".
  "cat $input | ".
  "fa_line_format $ignore_case | ";

if("" ne $remove_equal) {
  $command = $command .
    "perl $rm_dup_tmp1 | " ;
}

$command = $command .
  "fa_align $align_paramters | ".
  "fa_align2chain --out-ows=$out_ows | ".
  "sort | ".
  "fa_chains2mindfa > $out_fsm " ;

`$command` ;


#
#  *** Remove temporary files ***
#

END {
    if (-e $rm_dup_tmp1) {
        unlink ($rm_dup_tmp1);
    }
}
