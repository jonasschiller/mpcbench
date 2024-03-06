#Set Intersection using Bitonic Merge Sort
#Pre implemented using numpy functionality
#Probably quicker than naive implementation

from mpyc.runtime import mpc
import numpy as np
import traceback
import random
import sys
import time
import numpy as np

secnum = mpc.SecInt()


async def main():
    
    if len(sys.argv) > 1:
        input_size = int(sys.argv[1])
    else:
        print("No argument provided.")
    start = 1  # Start range
    end = 100000  # End range
    input1 = np.sort(np.random.permutation(np.arange(start, end+1))[:input_size]).tolist()    
    input2 = np.sort(np.random.permutation(np.arange(start, end+1))[:input_size])[::-1].tolist()
    
    x = list(map(secnum, input1+input2))  # secret input
    async with mpc:
        x = mpc.sorted(x)  # sort on absolute value
        for i in range(0,len(x),2):
            x[i]=mpc.if_else(x[i] == x[i + 1], x[i], 0)
            x[i+1]=secnum(0)
        mpc.random.shuffle(secnum, x)
        print('Sorted by absolute value:', await mpc.output(x))
    

if __name__ == '__main__':
    mpc.run(main())