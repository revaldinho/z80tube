#!/bin/tcsh -f

iDSK tubedev.dsk -n
iDSK tubedev.dsk -i ../TUBE.ASC
iDSK tubedev.dsk -i ../TUBE2.ASC

foreach f ( e-spigot-rev pi-spigot-rev sieve bigsieve nqueens math32 )
    python ../lst2hex.py ../../../opc/opc7/tests/${f}.lst > ${f}.hex
    iDSK tubedev.dsk -i ${f}.hex
end

# BCPL tests
#     awk '{printf "%s%c%c",$0,13,10} END{printf "%c",26}'
#
#foreach f ( apfel enig hello fact sphere)
foreach f ( enig hello fact sphere)
     python ../lst2hex.py ../../../opc/opc7/bcpltests/${f}.lst > ${f}.hex
     iDSK tubedev.dsk -i ${f}.hex
 end


