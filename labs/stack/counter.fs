\ FILE: stack/counter.fs
\ Een variabele in het datageheugen die tot 5 telt.
VARIABLE teller
: ophogen  teller @ 1 + teller ! ;

0 teller !
BEGIN
   ophogen
   teller @ 5 =
UNTIL
teller @
