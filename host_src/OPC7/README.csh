#!/bin/tcsh -f

iDSK tubedev.dsk -n
iDSK tubedev.dsk -i ../TUBE6.ASC

foreach f ( e-spigot-rev sieve bigsieve )
    python ../lst2data.py ../../../opc/opc7/tests/${f}.lst > ${f}.asc
    iDSK tubedev.dsk -i ${f}.asc
end


foreach f ( \
    hello \
    fact )
    python ../lst2data.py ../../../opc/opc7/bcpltests/${f}.lst > ${f}.asc
    iDSK tubedev.dsk -i ${f}.asc
end


