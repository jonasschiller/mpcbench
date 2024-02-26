# Original Author Philipp Eisermann 
# Original Source https://github.com/Philipp-Eisermann/sevareparser
# Adapted version
# testing with dir="sevaremeasurements/results/2022-08/09_07-59-42"

import argparse
import os
import subprocess

colors = ['black', 'blue', 'brown', 'cyan', 'darkgray', 'gray', 'green', 'lightgray', 'lime', 'magenta', 'olive',
          'orange', 'pink', 'purple', 'red', 'teal', 'violet', 'white', 'yellow']


# Input: protocol, String
# Output: Integer (-1 -> did not find protocol, 0 -> mal_dis, 1 -> mal_hon, 2 -> semi_dis, 3 -> semi_hon)
def get_security_class(prot):
    protocols_mal_dis = ["mascot", "lowgear", "highgear", "chaigear", "cowgear", "spdz2k", "tinier", "real-bmr"]
    protocols_mal_hon = ["sy-shamir", "malicious-shamir", "malicious-rep-field", "ps-rep-field", "sy-rep-field",
                          "brain", "malicious-rep-ring", "ps-rep-ring", "sy-rep-ring", "malicious-rep-bin",
                         "malicious-ccd", "ps-rep-bin", "mal-shamir-bmr", "mal-rep-bmr"]
    protocols_semi_dis = ["hemi", "semi", "temi", "soho", "semi2k", "semi-bmr", "semi-bin", "yao", "yaoO"]
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
        return -1


def get_security_class_name(class_nb):
    if class_nb == 0:
        return "Malicious,Dishonest_Majority"
    if class_nb == 1:
        return "Malicious,Honest_Majority"
    if class_nb == 2:
        return "Semi-Honest,Dishonest_Majority"
    if class_nb == 3:
        return "Semi-Honest,Honest_Majority"


# Is used to generate the axis labels of plots
def get_name(prefix_):
    prefix_names = ["Latency (ms)", "Bandwidths (Mbit/s)", "Packet Loss (%)", "Frequency (GHz)", "Quotas(%)",
                    "CPU Threads", "Input Size"]  # Axis names
    prefixes_ = ["Lat_", "Bdw_", "Pdr_", "Frq_", "Quo_", "Cpu_", "Set_"]

    if prefix_ in prefixes_:
        return prefix_names[prefixes_.index(prefix_)]
    return prefix_


def generate_tex_plot(tex_name, exp_prefix, included_protocols):
    """
    Creates a .tex file for a single 2D plot
    :param tex_name: name of the tex file
    :param exp_prefix: prefix (giving the experiment variable(s)) of the datafile
    :param included_protocols: list of protocol names to be included in the plot
    // Path + prefix + included_protocol must point to the txt datafile of the protocol
    """
    path = "/parsed/2D/"
    tex_writer = open(tex_name, "w")
    tex_writer.write(r'\documentclass[8pt]{beamer}')

    tex_writer.write("\\setbeamertemplate{itemize item}{$-$}\n")
    tex_writer.write("\\usepackage{pgf}\n")
    tex_writer.write("\\usepackage{pgfplots}\n")
    tex_writer.write("\\pgfplotsset{compat=newest}\n\n")

    tex_writer.write("\\begin{document}\n\n")

    tex_writer.write("\\begin{frame}\n")
    # tex_writer.write("    \\frametitle{MP-Slice Runtimes Datatype -d 1}\n")
    tex_writer.write("    \\begin{figure}\n")
    tex_writer.write("        \\begin{tikzpicture}\n")
    tex_writer.write("            \\begin{axis}[\n")
    tex_writer.write("                xlabel={" + get_name(exp_prefix) + "}, ylabel={runtime [s]},legend style={anchor=west, legend pos=outer north east}]\n")

    for g in range(len(included_protocols)):
        tex_writer.write("                \\addplot[mark=|, color= " + colors[g] + ",   thick] table {../../../" + path + exp_prefix + included_protocols[g] + ".txt};\n")

    tex_writer.write("                \\legend{")

    for included_protocol in included_protocols:
        tex_writer.write(included_protocol + ",")

    tex_writer.write("}\n")
    tex_writer.write("            \\end{axis}\n")
    tex_writer.write("        \\end{tikzpicture}\n")

    tex_writer.write("        \\begin{itemize}\n")
    tex_writer.write("            \\item Ref.Problem: Scalable Search\n")
    tex_writer.write("            \\item Library: MP-Slice - Datatype -d 1\n")
    tex_writer.write("            \\item Metric: input size - runtime\n")
    tex_writer.write("            \\item Specs: D-1518(2.2GHz) 32GiB 1Gbits\n")
    tex_writer.write("        \\end{itemize}\n")

    tex_writer.write("    \\end{figure}\n")
    tex_writer.write("\\end{frame}\n")
    tex_writer.write("\\end{document}")

    tex_writer.close()


def generate_tex_3Dplot(tex_name, exp_prefix, included_protocol):
    """
        Creates a .tex file for a single 3D plot
        :param tex_name: name of the tex file
        :param exp_prefix: prefix (giving the experiment variable(s)) of the datafile
        :param included_protocol: String name of the protocol to be plotted (can only be one)
        // Path + prefix + included_protocol must point to the txt datafile of the protocol
    """
    var1 = exp_prefix[:4]
    var2 = exp_prefix[4:8]
    path = "/parsed/3D/"
    tex_writer = open(tex_name, "w")
    tex_writer.write(r'\documentclass[8pt]{beamer}')

    tex_writer.write("\\setbeamertemplate{itemize item}{$-$}\n")
    tex_writer.write("\\usepackage{pgf}\n")
    tex_writer.write("\\usepackage{pgfplots}\n")
    tex_writer.write("\\pgfplotsset{compat=newest}\n\n")

    tex_writer.write("\\begin{document}\n\n")

    tex_writer.write("\\begin{frame}\n")
    # tex_writer.write("    \\frametitle{MP-Slice Runtimes Datatype -d 1}\n")
    tex_writer.write("    \\begin{figure}\n")
    tex_writer.write("        \\begin{tikzpicture}\n")
    tex_writer.write("            \\begin{axis}[\n")
    tex_writer.write("                xlabel={" + get_name(var1) + "}, ylabel={" + get_name(var2) + "}, zlabel={runtime [s]}]\n")
    tex_writer.write("                \\addplot3[surf] table {../../.." + path + exp_prefix + included_protocol + ".txt};\n")
    tex_writer.write("            \\end{axis}\n")
    tex_writer.write("        \\end{tikzpicture}\n")

    tex_writer.write("        \\begin{itemize}\n")
    tex_writer.write("            \\item Ref.Problem: Scalable Search\n")
    tex_writer.write("            \\item Library: MP-Slice - Datatype -d 1\n")
    tex_writer.write("            \\item Metric: input size - runtime\n")
    tex_writer.write("            \\item Specs: D-1518(2.2GHz) 32GiB 1Gbits\n")
    tex_writer.write("        \\end{itemize}\n")

    tex_writer.write("    \\end{figure}\n")
    tex_writer.write("\\end{frame}\n")
    tex_writer.write("\\end{document}")

    tex_writer.close()


# - - - - - - - - ARGUMENTS - - - - - - - - - - -

parser = argparse.ArgumentParser(
    description='This program plots the results parsed by sevare parser.')

parser.add_argument('filename', type=str,
                    help='Required, name of the test-run folder (usually of the form MONTH-YEAR).')

args = parser.parse_args()

filename = args.filename

if filename[len(args.filename) - 1] != '/':
    filename += '/'

# - - - - - - - - - INIT  - - - - - - - - - - - - -
# Check if the parser was executed before
if "parsed" not in os.listdir(filename):
    print("Could not find the parsed directory, make sure you executed SevareParser before calling the plotter.")
    exit()

# Create directories
os.mkdir(filename + "plotted/")
os.mkdir(filename + "plotted/2D")

# - - - - - - - - CREATE 2D PLOTS - - - - - - - - - - -

data_names = os.listdir(filename + "parsed/2D/")

prefixes = []  # will contain the variables for 2D plotting
last = ""

print("Commencing 2D Plotting...")
# look at what variables were used in the experiment
for data in data_names:
    # only 2D files, so always 3 char long prefix for variable
    if last != data[0:4] and data[0] != '.':
        last = data[0:4]
        if last not in prefixes:
            prefixes += [last]
            # We want one directory for multiple graphs per variable
            # Its name should be the prefix without the tailing '_'
            os.mkdir(filename + "plotted/2D/" + last[:len(last) - 1])

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
            print(data)
            protocol_name = data[4:(len(data) - 4)]
            if get_security_class(protocol_name) == -1:
                print("- Protocol " + protocol_name + " not recognized.")
            else:
                print(protocol_name)
                protocols[get_security_class(protocol_name)] += [protocol_name]

    # create plots
    for i in range(4):  # for each security class
        if not protocols[i]:
            continue

        # Fill up info of this security class
        generate_tex_plot(filename + "plotted/2D/" + prefix[:len(last) - 1] + "/" + get_security_class_name(i) + ".tex", prefix, protocols[i])

        print("- saved: " + "plotted/2D/" + prefix[:len(last) - 1] + "/" + get_security_class_name(i) + ".tex")

# Generate cost of security plots
print("Generating cost of security tex files")
info2D_reader = open(filename + "parsed/runtimes2D.txt", "r")
os.mkdir(filename + "plotted/2D/CostOfSecurity/")
info_lines = info2D_reader.readlines()
index = 0
while index < len(info_lines) and info_lines[index] != "Winners:\n":
    index += 1

if index >= len(info_lines):
    print("Did not find winners in info file.")
else:
    index += 1
    # For each variable, create a cost of security plot
    for i in range(len(info_lines) - index):
        exp_variable = info_lines[index + i].split(":")[0]
        winners = info_lines[index + i].split(":")[1].split(",")

        winners = [x for x in winners if x != '' and x != '\n']

        generate_tex_plot(filename + "plotted/2D/CostOfSecurity/" + exp_variable + ".tex", exp_variable, winners)
        print("-- saved: " + filename + "plotted/2D/CostOfSecurity/" + exp_variable + ".tex")

for i in range(len(prefixes)):
    prefixes[i] = prefixes[i][:3]

prefixes += ["CostOfSecurity"]

# Make tex files and remove auxiliary files
os.chdir(filename + "plotted/2D/")
for prefix in prefixes:
    os.chdir(prefix)
    latex_files = os.listdir()
    for latex_file in latex_files:
        if not latex_file.endswith(".tex"):
            continue
        # Compile the LaTeX file
        subprocess.call(["pdflatex", latex_file])

        # Remove auxiliary files
        aux_files = [f for f in os.listdir() if (f.endswith(".aux") or f.endswith(".snm") or f.endswith(".out") or f.endswith(".log") or f.endswith(".toc") or f.endswith(".nav"))]
        for f in aux_files:
            os.remove(f)

    os.chdir("../")

os.chdir("../../../")

prefixes.remove("CostOfSecurity")


# - - - - - - - - CREATE 3D PLOTS - - - - - - - - - - -
print("Commencing 3D plotting")

data_names = os.listdir(filename + "parsed/3D/")

data_names = [x for x in data_names if x != ".DS_Store"]

if len(data_names) == 0:
    print("No 3D plotting data found, exiting")
    exit()

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
            # print(protocol_name)
            # print(get_security_class(protocol_name))
            protocols[get_security_class(protocol_name)] += [protocol_name]

    # create plots
    for i in range(4):  # for each security class
        if not protocols[i]:
            continue

        for protocol in protocols[i]:

            generate_tex_3Dplot(filename + "plotted/3D/" + prefix[:len(last) - 1] + "/" + protocol + ".tex", prefix, protocol)

            # No check if data files contain valid info
            # No check if data files contain multiple values for each axis
            # Not automatically putting bdw for ex. on a particular axis

            # Create a plot for each protocol, sorted in its security class directory

            print("-- saved: " + "plotted/3D/" + prefix[:len(last) - 1] + "/" + protocol + ".pdf")

# Make tex files and remove auxiliary files
os.chdir(filename + "plotted/3D/")
for prefix in prefixes:
    os.chdir(prefix[:len(last) - 1])
    latex_files = os.listdir()
    for latex_file in latex_files:
        if not latex_file.endswith(".tex"):
            continue
        # Compile the LaTeX file
        subprocess.call(["pdflatex", latex_file])

        # Remove auxiliary files
        aux_files = [f for f in os.listdir() if (f.endswith(".aux") or f.endswith(".snm") or f.endswith(".out") or f.endswith(".log") or f.endswith(".toc") or f.endswith(".nav"))]
        for f in aux_files:
            os.remove(f)

    os.chdir("../")

os.chdir("../../../")

# Change exit() at check if 3D data exists if wanting to extend script!