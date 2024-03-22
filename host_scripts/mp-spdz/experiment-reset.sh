#!/bin/bash

# exit on error
set -e
# log every command
set -x

REPO_DIR=$(pos_get_variable repo_mpspdz_dir --from-global)

cd "$REPO_DIR"

rm -rf Programs/Bytecode/*