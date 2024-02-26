#!/bin/bash

#Output styling
Green='\033[0;32m'
Red='\033[0;31m'
Orange='\033[0;33m'
Yellow='\033[1;33m'
Cyan='\033[0;36m'
Stop='\e[0m'
okfail() {
    if [ "$1" = ok ]; then
        echo -e "[ ${Green}ok${Stop} ] $2"
    else
        echo -e "[${Red}fail${Stop}] $2"
    fi
}
warning() {
    echo -e "[${Orange}warn${Stop}] $1"
}
styleGreen() {
    echo -e "${Green}$1${Stop}"
}
styleOrange() {
    echo -e "${Orange}$1${Stop}"
}
styleRed() {
    echo -e "${Red}$1${Stop}"
}
styleYellow() {
    echo -e "${Yellow}$1${Stop}"
}
styleCyan() {
    echo -e "${Cyan}$1${Stop}"
}