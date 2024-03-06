
# Bitwise operation for 1.000.000 leads to a system fautlt due to too much RAM usage
# We do 100000 instead
import numpy as np
from mpyc.runtime import mpc
import sys
async def main():
    if len(sys.argv) > 1:
        size = int(sys.argv[1])
    else:
        size=10000
        print("No argument provided.")
    intarray=np.ones(size,dtype=int)
    secnum = mpc.SecInt(1)
    await mpc.start()
    test=secnum.array(intarray)
    sechelp=secnum(1)
    for i in range(size-1):
        sechelp=mpc.and_(test[i],test[i])
    await mpc.output(sechelp)
    await mpc.shutdown()
if __name__ == '__main__':
    mpc.run(main())