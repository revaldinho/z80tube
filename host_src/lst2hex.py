# lst2data.py <assembler_listing> > ASCII BASIC DATA statements

import re
import sys


debug=0
bytesperline=32

code_re = re.compile("([0-9a-f]+):\s*([0-9a-f]{8}.*)")
hex_re  = re.compile("^[0-9a-f]{8}$")

print( "# Source:", sys.argv[1],chr(13))

databytes = []

with open(sys.argv[1],"r") as f:
    for l in f.readlines():
        mobj = code_re.match(l)
        if mobj:
            adr = int(mobj.group(1),16)
            line = mobj.group(2)
            words = line.split()
            for w in words:
                if hex_re.match(w) :
                    if adr >= 0x1000:
                        for i in range (0, 4):
                            databytes.append(int(w,16)>>(i*8) & 0xFF)
                else:
                    break

idx = 0
adr = 0x1000
if debug:
    print ("%06X: " % adr, end="")
for d in databytes:
  print ("%02X"%d, end="")
  idx+=1  
  if idx % bytesperline==0:
     print(chr(13))

     if debug:
         adr+=8           
         print ("%06X: " % adr, end="")
     
if ((idx-1)%bytesperline != 0):
    print(chr(13))
print(chr(26))


        

