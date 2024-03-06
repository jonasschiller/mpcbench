# Reveal 1000000 integers
import numpy as np
from mpyc.runtime import mpc
import sys
async def main():
    if len(sys.argv) > 1:
        size = int(sys.argv[1])
    else:
        size=1000000
        print("No argument provided.")
    intarray=np.ones(size,dtype=int)
    secnum = mpc.SecInt(32)
    await mpc.start()
    test=secnum.array(intarray)
    mpc.output(test)
    await mpc.shutdown()
if __name__ == '__main__':
    mpc.run(main())