#! /usr/bin/python3

from random import randint, seed, random
import sys

rrange = 1
float_precision = 6

def get_random_set(n: int):
        if rrange < n:
                print("range >= amount must be true for unique sets")
                print("(range)", rrange,"<", n,"(amount), please change to reasonable constellation")
                exit(1)
        rand_set = set()
        while len(rand_set) < n:
                rand_set.add(randint(1, rrange))
        return rand_set

def get_random_tupel(n: int):
        return [randint(1, rrange) for i in range(n)]

def get_random_matrix(n: int):
        return [get_random_tupel(n) for i in range(n)]
        
def get_random_float_tupel(n: int):
        return [randint(1, n) + round(random(), float_precision) for i in range(n)]

def get_random_float_matrix(n: int):
        return [get_random_float_tupel(n) for i in range(n)]

def set_to_string(s: set):
        if (mode == 'b'):
                # return all numbers as binary, 0-padded to 64 bits
                return ' '.join(''.join(f'{num:064b}' for num in s))
        return ' '.join(map(str, s))

def matrix_to_string(m):
        return ' '.join(set_to_string(row) for row in m)

try:
        option = sys.argv[1][-1]
        n = int(sys.argv[2])
        rrange = int(sys.argv[3])
        seed(int(sys.argv[4]))
        filename = str(sys.argv[5])
        try:
                mode = sys.argv[6][-1]
        
        except:
                mode = "d"

        


except:
        print("Usage: ./inputgen.py <option> <amount> <range> <seed> <filename>")
        print("Options:")
        print("  -s: set,   Print <amount> many unique random numbers in range [1:<range>]")
        print("  -t: tupel, Print <amount> many random numbers in range [1:<range>]")
        print("  -f: float, Print <amount> many random numbers in range [1:<range>]")
        print("  -m: matrix, Print <amount>^2 many random numbers in range [1:<range>]")
        print("  -k: floatmatrix, Print <amount>^2 many random numbers in range [1:<range>]")
        print("Modes:")
        print("  -d: decimal base10, print numbers in decimal (default)")
        print("  -b: binary, print numbers in binary representation")

        exit()

# python3.9 and lower support
if (option == 't'):
        
        set_string = ""
        if (option == 't'):
                set_string = set_to_string(get_random_tupel(n))
        elif (option == 'f'):
                set_string = set_to_string(get_random_float_tupel(n))
        elif (option == 'm'):
                set_string = matrix_to_string(get_random_matrix(n))
        elif (option == 'k'):
                set_string = matrix_to_string(get_random_float_matrix(n))
        else:
                set_string = set_to_string(get_random_set(n))

        with open(filename, 'w') as file:
                file.write(set_string)

