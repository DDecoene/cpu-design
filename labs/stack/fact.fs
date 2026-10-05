\ FILE: stack/fact.fs
\ Faculteit met recursie. mul is vermenigvuldigen met herhaald optellen.
: mul ( a b -- a*b )
   0 SWAP                    \ a acc b
   BEGIN DUP WHILE
      1 -  >R                \ b-1 naar de terugkeerstapel
      OVER +                 \ acc = acc + a
      R>
   REPEAT
   DROP SWAP DROP ;

: fact ( n -- n! )
   DUP 1 = IF DROP 1 ELSE DUP 1 - fact mul THEN ;

5 fact
