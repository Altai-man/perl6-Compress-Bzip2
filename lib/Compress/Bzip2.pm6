use v6;
use Compress::Bzip2::Raw;
use NativeCall;

unit module Compress::Bzip2;

our sub handleOpenError(int32 $bzerror is rw, $bz, $handle) {
    given $bzerror {
	when BZ_CONFIG_ERROR { close($handle); die "Bzlib2 library has been mis-compiled." }
	when BZ_PARAM_ERROR {
	    if ($handle == $null) {
		die "Filename is incorrect.";
	    } else {
		close($handle);
		die "BlockSize value is incorrect.";
	    }
	}
	when BZ_IO_ERROR {
	    close($handle);
	    die "IO error with given filename.";
	}
	when BZ_MEM_ERROR {
	    close($handle);
	    die "Not enough memory for compression.";
	}
	default {
	    close($handle);
	    die "Something really bad happened with file reading.";
	}
    };

}

our sub handleWriteError(int32 $bzerror is rw, $bz, $handle, $len) {
    given $bzerror {
	when BZ_PARAM_ERROR {
	    if $handle == $null { die "Filename is incorrect." }
	    elsif $len < 0 { close($handle); die "Lenght of file is lower than zero." }
	} 
	when BZ_SEQUENCE_ERROR { close($handle); die "Incorrect open function was used, 'r' instead of 'w'." }
	when BZ_IO_ERROR { close($handle); die "IO error." }
    }
}

our sub handleCloseError(int32 $bzerror is rw, $handle) {
    # We can send null and zero here because closeError
    # can be only BZ_SEQUENCE_ERROR or BZ_IO_ERROR.
    # $handle will be closed.
    handleWriteError($bzerror, $null, $handle, 0);
}

our sub handleReadError(int32 $bzerror is rw, $bz, $handle, $len) {
    given $bzerror {
	# Code here is copied. TODO: elegance system of exceptions without spagetti code.
	when BZ_PARAM_ERROR {
	    if $handle == $null { die "Filename is incorrect." }
	    elsif $len < 0 { close($handle); die "Lenght of file is lower than zero." }
	}
	when BZ_SEQUENCE_ERROR { close($handle); die "Incorrect open function was used, 'w' instead of 'r'." }
	when BZ_IO_ERROR { close($handle); die "IO error." }
	when BZ_UNEXPECTED_EOF { close($handle); die "File is unfinished." }
	when BZ_DATA_ERROR { close($handle); die "Data integrity error was detected." }
	when BZ_DATA_ERROR_MAGIC { close($handle); die "Stream does not begin with magic bytes." }
	when BZ_MEM_ERROR {
	    close($handle);
	    die "Not enough memory for compression.";
	}
    }
}

our sub compress(Str $filename) is export {
    my int32 $bzerror;
    # FD, Blob, Size.
    my @info = name-to-compress-info($filename);
    my $bz = bzWriteOpen($bzerror, @info[0]);
    handleOpenError($bzerror, $bz, @info[0]) if $bzerror != BZ_OK;
    my $len = @info[2];
    BZ2_bzWrite($bzerror, $bz, @info[1], $len);
    handleWriteError($bzerror, $bz, @info[0], $len) if $bzerror != BZ_OK;
    bzWriteClose($bzerror, $bz);
    handleCloseError($bzerror, @info[0]) if $bzerror != BZ_OK;
    close(@info[0]);
}

our sub decompress(Str $filename) is export {
    my @info = name-to-decompress-info($filename);
    # FD, opened stream.
    my int32 $bzerror = BZ_OK;
    my $bz = bzReadOpen($bzerror, @info[0]);
    handleOpenError($bzerror, $bz, @info[0]) if $bzerror != BZ_OK;
    loop (;$bzerror != BZ_STREAM_END && $bzerror == BZ_OK;) {
	my $temp = buf8.new;
	$temp[1023] = 0; # We will read in chunks of 1024 bytes.
	my $len = BZ2_bzRead($bzerror, $bz, $temp, 1024);
	handleReadError($bzerror, $bz, @info[0], $len) if $bzerror != BZ_OK;
	@info[1].write($temp);
    }
    BZ2_bzReadClose($bzerror, $bz);
    handleCloseError($bzerror, @info[0]) if $bzerror != BZ_OK;
    @info[1].close(); # We close file descriptor of perl.
    close(@info[0]); # And we close FILE* of C.
}
