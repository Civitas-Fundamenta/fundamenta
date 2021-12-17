#!/bin/bash
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(cd "$(dirname "${dir}")" && pwd)"

source ${dir}/lib/ui.sh

function compile() {
    rm -rf ${dir}/build
    truffle compile --all
}

function ganache() {
    ganache-cli --chainId 1337 \
        --account "0x6269c3f5570892d46487ddce92e249ff4ba339f588cfba7b1bc39711d9804529,1000000000000000000000" \
        --account "0xd36984b800f652e08184137268000f7e7b590ddb7292aac6cb37031365f3c4d9,1000000000000000000000" \
        --account "0x798d7c41754630115ce7ce3bbc51089ed026e8ed9236c321a02fd32bf79dac29,1000000000000000000000" \
        --account "0x85756f3d62819426d7215f918a798235d9bb95a687ce25ea540171f244d49ebe,1000000000000000000000"

    exit
}

function test() {
    if [ $# -ne 1 ]; then
        echo "Incorrect number of arguments. Usage truffle.sh test <ContractName>"
        exit
    fi

    truffle test --network development ${dir}/tests/$1.js #--show-events

    exit
}

function exec() {

    _getCommonParams

    echo "Network:" ${NETWORK}
    echo "  Args:" $2 $3 $4 $5 $6 $7

    echo -n "Are you 100% sure (y/n)? "
    read confirm

    if [ "${confirm}" != "${confirm#[Yy]}" ]; then
        truffle exec --network ${NETWORK} ${dir}/scripts/$1.js $2 $3 $4 $5 $6 $7
    else
        echo Cancelled
    fi

    exit
}

$1 $2 $3 $4 $5 $6 $7

GR='\033[0;32m'
NC='\033[0m'

echo -e "${GR}Available options${NC}"
echo -e "${GR}ganache${NC}: Starts a ganache instance"
echo -e "${GR}test${NC}: Run a test script"
echo -e "${GR}verify${NC}: Verifies a contract"
echo -e "${GR}exec${NC}: Execute a script"
