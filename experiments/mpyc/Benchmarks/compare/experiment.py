from mpyc.runtime import mpc
import numpy as np
import sys

async def main():
    if len(sys.argv) > 1:
        size = int(sys.argv[1])
    else:
        size=10000
        print("No argument provided.")
    intarray=np.ones(size,np.int32)
    secnum = mpc.SecInt(32)
    # Securely multiply the arrays using mpyc
    await mpc.start()
    # Load the array
    a=secnum.array(intarray)
    intermed=mpc.np_less(a,a)
    result = await mpc.output(intermed[-1])
    await mpc.shutdown()
    print(result)
if __name__ == '__main__':
    mpc.run(main())