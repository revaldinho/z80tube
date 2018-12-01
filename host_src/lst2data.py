# lst2data.py <assembler_listing> > ASCII BASIC DATA statements

import re
import sys
code_re = re.compile("([0-9a-f]+):\s*((:?[0-9a-f]+).*)")
hex_re  = re.compile("^[0-9a-f]{8}$")

print( "10000 'Source:", sys.argv[1], end='')
lineno = 10010

with open(sys.argv[1],"r") as f:
    idx=0
    for l in f.readlines():
        mobj = code_re.match(l)
        if mobj:
            adr = int(mobj.group(1),16)
            line = mobj.group(2)
            words = line.split()
            offset = 0
            for w in words:
                if hex_re.match(w) :
                    adr += offset
                    if adr >= 0x1000:
                        adrbytes = []
                        databytes = []
                        for i in range (0, 4):
                            adrbytes.append(adr>>(i*8) & 0xFF)
                            databytes.append(int(w,16)>>(i*8) & 0xFF)
                        if ( idx%4==0):
                            print(chr(13))
                            print( lineno, "DATA ", end='')
                            lineno += 10
                        else:
                            print( ",", end='')                            
                        #print(",".join('&%02X' % i for i in databytes), end='')
                        print(",".join('%d' % i for i in databytes), end='')
                        idx +=1
                else:
                    break
            
    print( chr(13))
    print( lineno, "DATA -1" + chr(13))
    print(chr(26))


        

