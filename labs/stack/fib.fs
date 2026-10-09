\ Het n-de Fibonacci-getal met een lus.
: fib ( n -- fib )
   0 1 ROT                   \ x y n
   BEGIN DUP WHILE
      1 - >R                 \ x y         R: n-1
      SWAP OVER +            \ y x+y
      R>
   REPEAT
   DROP DROP ;

10 fib
