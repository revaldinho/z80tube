#!/bin/tcsh -f

iDSK tubedev.dsk -n
iDSK tubedev.dsk -i ../TUBE7.ASC

foreach f ( e-spigot-rev pi-spigot-rev sieve bigsieve nqueens math32 )
    python ../lst2hex.py ../../../opc/opc7/tests/${f}.lst > ${f}.hex
    iDSK tubedev.dsk -i ${f}.hex
end


# BCPL tests 
foreach f ( \
     apfel \
     hello \
     fact )
     python ../lst2hex.py ../../../opc/opc7/bcpltests/${f}.lst > ${f}.hex
     iDSK tubedev.dsk -i ${f}.hex
 end


