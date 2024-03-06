"""Example for Secure Auctions as a double auction

We want to enable trading of goods between different parties by finding the best possible price for both parties.
This is done by using a double auction, where both sides create bids and offers.
For this we use a SecureBid and a SecureOffer Class based on lists

"""


from mpyc.runtime import mpc

from typing import List  
from dataclasses import dataclass  
import numpy as np
import sys

secint=mpc.SecInt(32)
 

async def ComputeClearingPrice(PriceRange,size): 
    bids_prices = mpc.SecInt(32).array(5*np.ones(size,np.int32))
    bids_quantities = mpc.SecInt(32).array(5*np.ones(size,np.int32))
    offers_prices = mpc.SecInt(32).array(5*np.ones(size,np.int32))
    offers_quantities = mpc.SecInt(32).array(5*np.ones(size,np.int32))
    l=secint(0)
    smallest_z=secint(100000)
    this_z=secint(0)
    for i in range (1, PriceRange):
        accumulatedSupply=0
        accumulatedDemand=0
        bid_comp=mpc.np_less(bids_prices,i)
        offer_comp=mpc.np_less(i,offers_prices)
        accumulatedSupply=mpc.sum(list(mpc.np_multiply(offers_quantities,offer_comp)))
        accumulatedDemand=mpc.sum(list(mpc.np_multiply(bids_quantities,bid_comp)))
        this_z=accumulatedSupply-accumulatedDemand
        l=mpc.if_else(mpc.abs(this_z)<mpc.abs(smallest_z),i,l)
        smallest_z=mpc.if_else(mpc.abs(this_z)<=mpc.abs(smallest_z),this_z,smallest_z)
    return l       
        
                
async def main():               
    # Create market instance and test orders
    if len(sys.argv) == 2:
        input_size = int(sys.argv[1])
        price_range= 10
    elif len(sys.argv) == 3:
        input_size = int(sys.argv[1])
        price_range= int(sys.argv[2])
    else:
        print("No argument provided.")
    await mpc.start() 

    price=await ComputeClearingPrice(price_range,input_size)
    print(await mpc.output(price)) 
    await mpc.shutdown()
    
       
if __name__ == '__main__':
    mpc.run(main())