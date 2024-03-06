import numpy as np
from mpyc.runtime import mpc
import mpyc.gmpy as gmpy2
import sys
async def main():

    if len(sys.argv) > 1:
        size = int(sys.argv[1])
    else:
        size=10000
        print("No argument provided.")

    # Rest of the code...
    # Securely multiply the arrays using mpyc
    await mpc.start()
    secarray=mpc.SecFxp(32,8).array
    input=secarray(np.ones(size,np.int32))
    for i in range(size):
        intermed=(input[i]/input[i])
    result = await mpc.output(intermed)
    print(result)
    await mpc.shutdown()
if __name__ == '__main__':
    mpc.run(main())