from mpyc.runtime import mpc
import mpyc.gmpy as gmpy2
import numpy as np
import sys

async def main():
    if len(sys.argv) > 1:
        size = int(sys.argv[1])
    else:
        size=1000000
        print("No argument provided.")
    # Securely multiply the arrays using mpyc
    secarray=mpc.SecInt(32).array
    input=np.zeros(size,np.int32)
    await mpc.start()
    intermed=mpc.np_multiply(secarray(input),secarray(input))
    await mpc.output(intermed[-1])
    await mpc.shutdown()
if __name__ == '__main__':
    mpc.run(main())