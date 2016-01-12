use v6;
use Compress::Bzip2::Raw;
use NativeCall;

unit module Compress::Bzip2;

our $null = Pointer[uint32].new(0);

our sub name-to-blob(Str $filename) {
    my $blob = slurp $filename, :bin;
    $blob;
    # my $len = $blob.elems;
    # my @array;
    # @array[0] = $blob;
    # @array[1] = $len;
    # @array;
}

our sub handleWriteOpenError(int32 $bzerror, $handle, $blockSize100k) {
    given $bzerror {
	when BZ_CONFIG_ERROR { die "Bzlib2 library has been mis-compiled." }
	when BZ_PARAM_ERROR {
	    if ($handle == $null) {
		die "Filename is incorrect.";
	    } elsif (($blockSize100k < 1) || ($blockSize100k > 9)) {
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
    # We can send null here because closeError
    # here can be only BZ_SEQUENCE_ERROR or BZ_IO_ERROR.
    handleWriteError($bzerror, $null, 0);
}

our sub compress(Str $filename) is export {
    my int32 $bzerror;
    my int32 $blockSize100k = 6; # Default level of compression.
    my int32 $verbosity = 1;
    my int32 $workFactor = 0; # Default case.

    my $array = CArray[uint8].new;
    my $handle = fopen(($filename ~~ m/.+\./) ~ "bz2", "wb");
    my $bz = BZ2_bzWriteOpen($bzerror, $handle, $blockSize100k, $verbosity, $workFactor);
    if $bzerror != BZ_OK {
	BZ2_bzWriteClose($bz);
	handleWriteOpenError($bzerror, $handle, $blockSize100k);
	close($handle);
    }
    my $blob = name-to-blob($filename);
    my $len = $blob.elems;
    $array[$_] = $blob[$_] for ^$len;
    BZ2_bzWrite($bzerror, $bz, $array, $len);
    handleWriteError($bzerror, $bz, $len);
    BZ2_bzWriteClose($bzerror, $bz, 0, $null, $null);
    handleWriteCloseError($bzerror);
}
