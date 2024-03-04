# Benchmark MPC programs in pos testing environments

sevarebench is an framework for running MPC protocols in a [pos](https://dl.acm.org/doi/10.1145/3485983.3494841) -enabled testbed environment. It was originally developed by Jakob Oberman [https://github.com/vyrovcz/sevarebench] and abstracted by Jonas Schiller [https://github.com/jonasschiller/sevarebenchabstract] to build the baseline for a general purpose MPC framework benchmarking tool. 

## Introduction

The sevarebench tool is implemented in the bash scripting language and its main purpose is to deploy and execute MPC programs on the TUM network testbed. For this, it relies on the pos framework designed for reliable and efficient management of network testbeds with a special focus on repeatability. It prepares the network settings and executes the program in six main steps. 
### Parameter Management
The first step includes the processing of the provided execution information. The framework accepts information from the command line through individual parameters or a configuration file. Here, one can select either specific values for environment settings such as bandwidth or parameter ranges. If ranges are provided, the framework will execute the experiment for each possible combination.
While most parameters are framework agnostic such as the chosen nodes or the desired network or host manipulation, some are highly framework specific. For MP-SPDZ this includes the protocol parameter. As the framework supports over 30 different protocols, a selection of the desired protocol can be made via the parameters. Here we need to implement a framework-specific solution that checks whether a correct selection of protocols has been made. In addition to that, some frameworks provide special compilation flags that change the utilized protocols or implementations. These are also framework-dependent and therefore need to be adapted.
### Nodes Setup
This step initializes the nodes by checking their current status, claiming them exclusively for the duration of the program execution, and installing the desired Linux version. For this, the framework relies heavily on the pos framework for testbed management, which provides extensive functionality for access and server management (https://dl.acm.org/doi/10.1145/3485983.3494841). This step is completely framework agnostic and does not require any adaptation towards a general benchmarking tool.
### Network Settings
The third step sets the network settings of the nodes. This includes the type of connection, the utilized interfaces, and the installation of required drivers. Here, the setup is highly dependent on the chosen nodes as well as the number of parties. As previously described, some nodes are connected via a switch, while others have direct links between each other. This information is defined in the framework, and the correct setup is chosen based on the selected nodes.
In the original framework, this step was also used to build the MP-SPDZ library. In order to separate the two workloads and enable a framework-independent setup, we moved the framework-building phase into the fourth setup phase.
### Framework Installation
In step four, the required dependencies, as well as the desired framework, are downloaded and installed on the different test nodes. This step is highly specific to each framework. If a framework requires to be built from scratch, the required building steps are performed as well. This section therefore has to be adapted to the specific needs of each framework. We provide an installation script template, which details the most important steps to integrate a new general purpose MPC framework into the test environment.
### Experiment Execution
In the fifth step, the experiment is executed on the nodes. 
Before execution, the previously selected network parameters are set using the tc (https://man7.org/linux/man-pages/man8/tc.8.html) command to modify the network behavior. Additionally, the computational power of the nodes can be reduced by limiting the CPU frequency or the CPU Quota. If multiple different scenarios should be executed, the framework automatically loops over each possible scenario and sets the correct environmental parameters. 
After everything is set up, the actual experiment can be run. Here, the term experiment describes the complete code required to run an MPC use case in a desired framework on a system where the framework is already installed. Here the frameworks specific compilation process heavily influences the execution process. While some frameworks require the experiment to be present during the initial installation, others allow the specific compilation of an experiment code file, while some do not require any sort of compilation. Therefore, the execution script must be adapted to the needs of the framework by implementing the required steps for program execution. The execution of the MPC protocol is then tracked using the linux /bin/time (https://man7.org/linux/man-pages/man1/time.1.html) command to extract the elapsed wall clock time, the required RAM, and the CPU usage. Furthermore, all execution output is piped into a measurement file. For each loop, a separate result file is generated containing the output of the experiment and the /bin/time command.
### Result Formatting and Export
The sixth and final step extracts the key performance metrics from the result files. These files differ between the frameworks, as some perform their own measurements during the execution. These are extracted by specifying a custom extraction method for each framework. Again, a template is provided for the integration of new frameworks. During the extraction phase, the text-based result files are parsed and all relevant information is piped into a csv file containing the performance metrics for each loop and environment setting. This table can then be exported to a specified Github repository for easy result extraction.
Finally, the script cleans the nodes and frees them for further use.

## How to

### To enable git-upload of the measurement data
To use this functionality, a repository to store the measurement results is required. How it would work with [github.com](https://github.com/new):

Change global-variables.yml in line "repoupload: git@github.com:reponame/sevaremeasurements.git" to your repository name.

Then you need a ssh key on your pos management server. Typically you can check for existing keys by running the command

```
less -e ~/.ssh/id_rsa.pub
```

If this displays your ssh public key (ssh-... ... user@host), you could use it in your git repo settings or create a new key-lock pair with 
```
ssh-keygen
```

Use the public key to create a new deploy key for your repository. Add a new Deploy key under "Deploy keys" in the repository settings. Activate "Allow write access". Or hand your public key to your repository admin.
[docs.github.com Deploy Keys](https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys)


### Start experiment measurement

1. Clone this repo on the pos management node into directory `sevarebench` and enter it

```
ssh -p 10022 <username>@<pos-management-server-hostname>
git clone https://github.com/vyrovcz/sevarebench.git
cd sevarebench
```

2. Reserve two or more nodes with pos to use with sevarebench

```
pos calendar create -s "now" -d 40 node1 node2 node3
```

3. Make `servarebench.sh` executable and test usage printing

```
chmod 740 sevarebench.sh
./sevarebench.sh
```

This should print some usage information if successful

4. Execute the testrun config to test functionality

```
./sevarebench.sh --config configs/testruns/testrunBasic.conf node1,node2,node3 &> sevarelog01 &
disown %-  # your shell might disown by default
```

This syntax backgrounds the experiment run and detaches the process from the shell so that it continues even after disconnect. Track the output of sevarebench in the logfile `sevarelog01` at any time with:

```
tail -F sevarelog01
```

Stuck runs should be closed with sigterm code 15 to the process owning all the testnodes processes. For example with 
```
htop -u $(whoami)
```
and F9. This activates the trap that launches the verification and exporting of the results that have been collected so far, which could take some time. Track the process in the logfile


### Add new experiment


Adding a new experiment depends on the  framework as some frameworks require experiments to be present during framework compilation while others allow for separate compilation.
The easiest way of adding an experiment is through storing the code in this repository in the experiment section and then copying the code to the required place once the server is setup either before or after framework installation


### Add new testbed nodes

New servers can simply be added through adding their network information in the global-variables.yml file together with their network topology.

#### Switch topology

In `global-variables.yml` simply add the following lines with the respective names for `testbed`, `node`, and `interfacename`

```
# testbedAlpha NIC configuration
node1NIC0: &NICtestbedA <interfacename>
node2NIC0: *NICtestbedA
...
node3NIC0: *NICtestbedA
```

#### Direct connection topology

Design and define node connection model. Recommended and intuitive is the circularly sorted approach like in the following example. Already implemented directly connected nodes are also defined in a circularly sorted fashion.


## Known limitations

### Only exporting measurements from first node

The measurement result data set is exported only from the first node of the node argument value when starting sevarebench.