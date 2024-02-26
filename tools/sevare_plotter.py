# Original Author Philipp Eisermann 
# Original Source https://github.com/Philipp-Eisermann/sevareparser
# Adapted version

import argparse
import os
import matplotlib.pyplot as plt
from matplotlib import cm
from matplotlib.ticker import MaxNLocator
import pickle

# SEVARE PLOTTER
# Will create a /plotted directory and write everything in there
# A folder is created for each variable combination type ("<var_name>*_) contained in /parsed
# In these folders a plot (.tex & .pdf) for each security class (if represented by at least 1 protocol) will be created


# Reads 2D data file and returns the x and y datapoints in arrays
def read_file(file_):
    x = []
    y = []
    d = None
    # fill up x and y
    d = file_.readlines()
    for lin in range(len(d)):
        dd = d[lin].split('\t')
        x.append(float(dd[0]))
        y.append(float(dd[1][0:len(dd[1]) - 1]))
    return x, y


def read_file_3D(file3D_):
    x1 = []
    y1 = []
    z1 = []
    d1 = file3D_.readlines()
    for lin3D in range(len(d1)):
        dd1 = d1[lin3D].split('\t')
        x1.append(float(dd1[0]))
        y1.append(float(dd1[1]))
        z1.append(float(dd1[2][:len(dd1[2]) - 1]))
    return x1, y1, z1


# Input: protocol, String
# Output: Integer (-1 -> did not find protocol, 0 -> mal_dis, 1 -> mal_hon, 2 -> semi_dis, 3 -> semi_hon)
def get_security_class(prot):
    protocols_mal_dis = ["mascot", "lowgear", "highgear", "chaigear", "cowgear", "spdz2k", "tinier", "real-bmr"]
    protocols_mal_hon = ["sy-shamir", "malicious-shamir", "malicious-rep-field", "ps-rep-field", "sy-rep-field",
                          "brain", "malicious-rep-ring", "ps-rep-ring", "sy-rep-ring", "malicious-rep-bin",
                         "malicious-ccd", "ps-rep-bin", "mal-shamir-bmr", "mal-rep-bmr"]
    protocols_semi_dis = ["hemi", "semi", "temi", "soho", "semi2k", "semi-bmr", "semi-bin"]
    protocols_semi_hon = ["atlas", "shamir", "replicated-field", "replicated-ring", "shamir-bmr", "rep-bmr",
                          "replicated-bin", "ccd"]
    if prot in protocols_mal_dis:
        return 0
    if prot in protocols_mal_hon:
        return 1
    if prot in protocols_semi_dis:
        return 2
    if prot in protocols_semi_hon:
        return 3
    else:
        print("ERROR: Protocol was not recognized")


def get_security_class_name(class_nb):
    if class_nb == 0:
        return "Malicious, Dishonest Majority"
    if class_nb == 1:
        return "Malicious, Honest Majority"
    if class_nb == 2:
        return "Semi-Honest, Dishonest Majority"
    if class_nb == 3:
        return "Semi-Honest, Honest Majority"


# Is used to generate the axis labels of plots
def get_name(prefix_):
    prefix_names = ["Latency (ms)", "Bandwidths (Mbit/s)", "Packet Loss (%)", "Frequency (GHz)", "Quotas(%)",
                    "CPU Threads", "Input Size"]  # Axis names
    prefixes_ = ["Lat_", "Bdw_", "Pdr_", "Frq_", "Quo_", "Cpu_", "Set_"]

    if prefix_ in prefixes_:
        return prefix_names[prefixes_.index(prefix_)]
    return prefix_


# For 3D plotting, x and y arrays need to have at least 2 different values
# Input: array of ints or floats
def is_non_changing(array_):
    last_ = array_[0]
    for element in array_:
        if element != last_:
            return False
    return True


# - - - - - - - - - - ARGUMENTS - - - - - - - - -

parser = argparse.ArgumentParser(
    description='This program plots the results parsed by sevare parser.')

parser.add_argument('filename', type=str,
                    help='Required, name of the test-run folder (usually of the form MONTH-YEAR).')

args = parser.parse_args()

filename = args.filename

if filename[len(args.filename) - 1] != '/':
    filename += '/'

# - - - - - - - - - INITIALISATION - - - - - -
# Check if the parser was executed before
if "parsed" not in os.listdir(filename):
    print("Could not find the parsed directory, make sure you executed SevareParser before calling the plotter.")
    exit()

colors = ['black', 'blue', 'brown', 'cyan', 'darkgray', 'gray', 'green', 'lightgray', 'lime', 'magenta', 'olive',
          'orange', 'pink', 'purple', 'red', 'teal', 'violet', 'white', 'yellow']

# Create directories
os.mkdir(filename + "plotted/")
os.mkdir(filename + "plotted/2D")
os.mkdir(filename + "saved/")
os.mkdir(filename + "saved/2D")

# - - - - - - - - CREATE 2D PLOTS - - - - - - - - - - -

data_names = os.listdir(filename + "parsed/2D/")

prefixes = []  # will contain the variables for 2D plotting
last = ""

print("Commencing 2D Plotting...")
# look at what variables were used in the experiment
for data in data_names:
    # only 2D files, so always 3 char long prefix for variable
    if last != data[0:4]:
        last = data[0:4]
        if last not in prefixes:
            prefixes += [last]
            # We want one directory for multiple graphs per variable
            # Its name should be the prefix without the tailing '_'
            os.mkdir(filename + "plotted/2D/" + last[:len(last) - 1])
            os.mkdir(filename + "saved/2D/" + last[:len(last) - 1])

# The runtime is in O(n*m) where n is nb of protocols and m nb of variables
# We need to go through all files for each variable to get all the datafiles for a variable to plot them together
for prefix in prefixes:
    # Will hold the filenames organized by security class for the prefix of this iteration
    protocols = [None] * 4
    for i in range(4):
        protocols[i] = []

    # sort in the 4 classes
    for data in data_names:
        if data[:4] == prefix:
            protocol_name = data[4:(len(data) - 4)]
            if get_security_class(protocol_name) == "error":
                print("- Protocol " + protocol_name + " not recognized.")
            else:
                protocols[get_security_class(protocol_name)] += [protocol_name]

    # create plots
    for i in range(4):  # for each security class
        if not protocols[i]:
            continue

        for protocol in protocols[i]:
            # Fill up info of this security class
            data_file_reader = open(filename + "parsed/2D/" + prefix + protocol + ".txt", "r")
            x, y = read_file(data_file_reader)
            fig, ax = plt.subplots()
            ax.plot(x, y, marker='x', label=protocol, linewidth=1.0)

        # Create plot for this security class
        ax.set_xlabel(get_name(prefix))
        ax.set_ylabel("Runtime (s)") # Datafiles always contain runtime values for the second coordinate
        # fig.ylabel("Runtime (s)")
        ax.legend()

        fig.savefig(filename + "plotted/2D/" + prefix[:len(last) - 1] + "/" + get_security_class_name(i) + ".pdf")
        print("- saved: " + "plotted/2D/" + prefix[:len(last) - 1] + "/" + get_security_class_name(i) + ".pdf")

        with open(filename + 'saved/2D/' + prefix[:len(last) - 1] + "/" + get_security_class_name(i), 'wb') as f:
            pickle.dump(fig, f)
        # fig.clf()

# Cost of security plots
print("Generating cost of security plots")
info2D_reader = open(filename + "parsed/info2D.txt", "r")
os.mkdir(filename + "plotted/2D/CostOfSecurity/")
info_lines = info2D_reader.readlines()
index = 0
while index < len(info_lines) and info_lines[index] != "Winners:\n":
    #print(info_lines[index])
    index += 1

if index >= len(info_lines):
    print("Did not find winners in info file.")
else:
    index += 1
    # For each variable, create a cost of security plot
    for i in range(len(info_lines) - index):
        #print(info_lines[index + i])
        exp_variable = info_lines[index + i].split(":")[0]
        winners = info_lines[index + i].split(":")[1].split(",")
        # print(winners)

        for winner in winners:
            if winner == '' or winner == '\n':
                continue
            # Fill up info of this security class
            data_file_reader = open(filename + "parsed/2D/" + exp_variable + winner + ".txt", "r")
            x, y = read_file(data_file_reader)
            plt.plot(x, y, marker='x', label=winner, linewidth=1.0)

        # Create plot for this security class
        plt.xlabel(get_name(exp_variable))
        plt.ylabel("Runtime (s)")  # Datafiles always contain runtime values for the second coordinate
        plt.legend()

        plt.savefig(filename + "plotted/2D/" + "CostOfSecurity/" + exp_variable + ".pdf")
        print("-- saved: " + filename + "plotted/2D/" + "CostOfSecurity/" + exp_variable + ".pdf")

        plt.clf()


# - - - - - - - - CREATE 3D PLOTS - - - - - - - - - - -
print("Commencing 3D plotting")

data_names = os.listdir(filename + "parsed/3D/")
os.mkdir(filename + "plotted/3D/")
prefixes = []

# look at what variables were used in the experiment
for data in data_names:
    # only 3D files -
    if data == ".DS_Store":
        continue
    if last != data[0:8]:
        last = data[0:8]
        if last not in prefixes:
            prefixes += [last]
            # We want one directory for multiple graphs per variable
            # Its name should be the prefix without the tailing '_'
            os.mkdir(filename + "plotted/3D/" + last[:len(last) - 1])

for prefix in prefixes:
    # Will hold the filenames organized by security class for the prefix of this iteration
    protocols = [None] * 4
    for i in range(4):
        protocols[i] = []

    # sort in the 4 classes
    for data in data_names:
        if data[:8] == prefix:
            protocol_name = data[8:(len(data) - 4)]
            #print(protocol_name)
            #print(get_security_class(protocol_name))
            protocols[get_security_class(protocol_name)] += [protocol_name]


    # create plots
    for i in range(4):  # for each security class
        if not protocols[i]:
            continue
        fig = plt.figure(figsize=(10, 10))
        ax = fig.add_subplot(111, projection='3d')
        for protocol in protocols[i]:

            data_file_reader = open(filename + "parsed/3D/" + prefix + protocol + ".txt", "r")
            x, y, z = read_file_3D(data_file_reader)

            # SOMETIMES ERROR HERE - BC OF ONLY INFO OF 1 DIM? (ex. x=[30,30,30,...]
            if not x or not y or not z:
                print(prefix + protocol + " couldn't be plotted, there is data missing for at least one dimension.")
                continue

            if is_non_changing(x) or is_non_changing(y):
                print(prefix + protocol + " couldn't be plotted, the x or y dimension is not represented for different points (or both).")
                continue

            # Bandwidth always has to be on the x axis for visibility reasons
            if "Bdw_" == prefix[4:8]:
                surf = ax.plot_trisurf(y, x, z, cmap=cm.jet, linewidth=0)
                plt.ylabel(get_name(prefix[:4]))
                plt.xlabel(get_name(prefix[4:8]))
            else:
                surf = ax.plot_trisurf(x, y, z, cmap=cm.jet, linewidth=0)
                plt.xlabel(get_name(prefix[:4]))
                plt.ylabel(get_name(prefix[4:8]))

            fig.colorbar(surf)
            ax.xaxis.set_major_locator(MaxNLocator(5))
            ax.yaxis.set_major_locator(MaxNLocator(6))
            ax.zaxis.set_major_locator(MaxNLocator(5))
            # plt.plot(x, y, marker='x', label=protocol, linewidth=1.0)
            fig.tight_layout()

            # Create a plot for each protocol, sorted in its security class directory

            # plt.zlabel("Runtime (s)")  # Datafiles always contain runtime values for the second coordinate
            #plt.legend()

            plt.savefig(filename + "plotted/3D/" + prefix[:len(last) - 1] + "/" + protocol + ".pdf")
            print("-- saved: " + "plotted/3D/" + prefix[:len(last) - 1] + "/" + protocol + ".pdf")
            plt.clf()


