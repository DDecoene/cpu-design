\ Uitwerkingen van de oefeningen: nuttige stapelwoorden.
: nip    SWAP DROP ;
: 2dup   OVER OVER ;
: negate INVERT 1 + ;
: 0=     0 = ;
: max    2dup < IF nip ELSE DROP THEN ;

3 7 max          \ 7
7 3 max          \ 7
5 negate         \ 251 (= -5 in 8 bit)
1 2 nip          \ 2
0 0=             \ 255 (waar)
