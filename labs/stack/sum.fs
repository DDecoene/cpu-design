\ Som van 1 tot n.
: som ( n -- s )
   0 SWAP                    \ acc n
   BEGIN DUP WHILE
      SWAP OVER +            \ n acc+n
      SWAP 1 -               \ acc' n-1
   REPEAT
   DROP ;

10 som
