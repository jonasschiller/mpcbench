#!/bin/bash
# shellcheck disable=SC2034

#####
## MP-SPDZ protocol definitions
##################

# supported protocols split by computational domain
supportedFieldProtocols=( mascot lowgear highgear cowgear chaigear semi hemi 
    temi soho malicious-shamir malicious-rep-field ps-rep-field sy-rep-field 
    shamir atlas replicated-field )
supportedRingProtocols=( spdz2k semi2k brain malicious-rep-ring ps-rep-ring 
    sy-rep-ring replicated-ring )
supportedBinaryProtocols=( tinier real-bmr semi-bin yao yaoO semi-bmr 
    malicious-rep-bin malicious-ccd ps-rep-bin mal-shamir-bmr mal-rep-bmr 
    replicated-bin ccd shamir-bmr rep-bmr )
# protocols split by adversary model
maldishonestProtocols=( mascot lowgear highgear spdz2k tiny tinier real-bmr )
covertdishonestProtocols=( cowgear chaigear )
semidishonestProtocols=( semi hemi temi soho semi2k semi-bin yao yaoO semi-bmr )
malhonestProtocols=( malicious-shamir malicious-rep-field ps-rep-field sy-rep-field 
    brain malicious-rep-ring ps-rep-ring sy-rep-ring malicious-rep-bin 
    malicious-ccd ps-rep-bin mal-rep-bmr mal-shamir-bmr )
semihonestProtocols=( shamir atlas replicated-field replicated-ring replicated-bin 
    ccd shamir-bmr rep-bmr )
# currently unsupported
supportedRingProtocols+=( rep4-ring )
##supportedBinaryProtocols+=( tiny )

# split by allowed party size, others allow any size
N2Protocols=( yao yaoO )
N3Protocols=( replicated-field malicious-rep-field brain ps-rep-field sy-rep-field
    malicious-rep-ring ps-rep-ring sy-rep-ring replicated-ring malicious-rep-bin
    ps-rep-bin replicated-bin )
# unsure if 3-player only
#N3Protocols+=( mal-rep-bmr rep-bmr)
N4Protocols=( rep4-ring )