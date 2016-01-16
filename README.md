perl6-Compress-Bzip2  [![Build Status](https://travis-ci.org/Altai-man/perl6-Compress-Bzip2.svg?branch=master)](https://travis-ci.org/Altai-man/perl6-Compress-Bzip2)
====================

Bindings to bzip2 library. Procedural API is as easy as pie: you can compress and decompress your files like this:

```perl6
compress($filename);
decompress($filename);
```

If you want to make a simple "from Buf to Buf" (de)compressing, you should use something like this:

```perl6
my buf8 $result = compressToBlob($data); # Data should be encoded.
# or
my Str $result = decompressToBlob($compressed-data).decode;
```

TODO
====================

* Docs.
* OO-interface.
