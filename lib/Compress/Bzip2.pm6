use v6;
use Compress::Bzip2::Raw;
use NativeCall;

unit module Compress::Bzip2;

our class X::Bzip2 is Exception {
    has $.action;
    has $.code;
    has $.handle; # FILE* pointer.

    method new ($action, $code, $handle) { self.bless(:$action,:$code,:$handle); }

    method message() {
	given $!code {
	    when BZ_CONFIG_ERROR {
		close($!handle);
		"Error during $.action: Bzlib2 library was mis-compiled.";
	    }
	    when BZ_PARAM_ERROR {
		if ($!handle == $null) {
		    "Error during $.action: Filename is incorrect.";
		} else {
		    close($!handle);
		    "Error during $.action: BlockSize value is incorrect or given file is empty.";
		}
	    }
	    when BZ_IO_ERROR {
		"Error during $.action: IO error with given filename.";
	    }
	    when BZ_MEM_ERROR {
		close($!handle);
		"Error during $.action: Not enough memory for compression.";
	    }
	    when BZ_SEQUENCE_ERROR {
		close($!handle);
		"Error during $.action: Incorrect open function was used."
	    }
	    when BZ_UNEXPECTED_EOF {
		close($!handle);
		"Error during $.action: File is unfinished."
	    }
	    when BZ_DATA_ERROR | BZ_DATA_ERROR_MAGIC {
		close($!handle);
		"Error during $.action: Data integrity error was detected."
	    }
	    default {
		close($!handle);
		"Error during $.action: Something really bad happened with file reading.";
	    }
	}
    }
}

our sub compress(Str $filename) is export {
    my int32 $bzerror;
    # FD, Blob, Size.
    my @info = name-to-compress-info($filename);
    my $bz = bzWriteOpen($bzerror, @info[0]);
    die X::Bzip2.new('bzWriteOpen', $bzerror, @info[0]) if $bzerror != BZ_OK;
    # I wonder how can I reduce this repeated 'die' part.
    my $len = @info[2];
    BZ2_bzWrite($bzerror, $bz, @info[1], $len);
    die X::Bzip2.new('bzWrite', $bzerror, @info[0]) if $bzerror != BZ_OK;
    bzWriteClose($bzerror, $bz);
    die X::Bzip2.new('bzWriteClose', $bzerror, @info[0]) if $bzerror != BZ_OK;
    close(@info[0]);
}

our sub decompress(Str $filename) is export {
    my int32 $bzerror = BZ_OK;
    # FD, opened stream.
    my @info = name-to-decompress-info($filename);
    my $bz = bzReadOpen($bzerror, @info[0]);
    die X::Bzip2.new('bzReadOpen', $bzerror, @info[0]) if $bzerror != BZ_OK;
    my buf8 $temp .= new;
    $temp[1023] = 0; # We will read in chunks of 1024 bytes.
    loop (;$bzerror != BZ_STREAM_END && $bzerror == BZ_OK;) {
	my $len = BZ2_bzRead($bzerror, $bz, $temp, 1024);
	if @info[1] {
	    @info[1].write($temp);
	}
    }
    if $bzerror != BZ_OK|BZ_STREAM_END {
	die X::Bzip2.new('bzRead', $bzerror, @info[0]);
    }
    BZ2_bzReadClose($bzerror, $bz);
    die X::Bzip2.new('bzReadClose', $bzerror, @info[0]) if $bzerror != BZ_OK;
    @info[1].close(); # We close file descriptor of perl.
    close(@info[0]); # And we close FILE* of C.
}
