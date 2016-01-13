use v6;
use Compress::Bzip2::Raw;
use NativeCall;

unit module Compress::Bzip2;

our sub handleWriteOpenError(int32 $bzerror, $handle) {
    given $bzerror {
	when BZ_CONFIG_ERROR { die "Bzlib2 library has been mis-compiled." }
	when BZ_PARAM_ERROR {
	    if ($handle == $null) {
		die "Filename is incorrect.";
	    } else {
		die "BlockSize value is incorrect.";
	    }
	}
	when BZ_IO_ERROR {
	    die "IO error with given filename.";
	}
	when BZ_MEM_ERROR {
	    die "Not enough memory for compression.";
	}
    };
}

our sub handleWriteError(int32 $bzerror is rw, $handle, $len) {
    given $bzerror {
	when BZ_PARAM_ERROR {
	    if $handle == $null { die "Filename is incorrect." }
	    elsif $len < 0 { die "Lenght of file is lower than zero." }
	} 
	when BZ_SEQUENCE_ERROR { die "Incorrect open function was used, 'r' instead of 'w'." }
	when BZ_IO_ERROR { die "IO error." }
    }
}

our sub handleWriteCloseError(int32 $bzerror is rw) {
    # We can send null and zero here because closeError
    # can be only BZ_SEQUENCE_ERROR or BZ_IO_ERROR.
    handleWriteError($bzerror, $null, 0);
}

our sub compress(Str $filename) is export {
    my int32 $bzerror;
    my $array = CArray[uint8].new;
    my @data = filename-to-info($filename);
    my $bz = bzWriteOpen($bzerror, @data[0]);
    if $bzerror != BZ_OK {
	bzWriteClose($bzerror, $bz);
	handleWriteOpenError($bzerror, @data[0]);
	close(@data[0]);
    }
    my $len = @data[2];
    $array[$_] = @data[1][$_] for ^$len;
    BZ2_bzWrite($bzerror, $bz, $array, $len);
    handleWriteError($bzerror, $bz, $len);
    bzWriteClose($bzerror, $bz);
    handleWriteCloseError($bzerror);
}
