
function _getCommonParams() {
    if [[ -z "${PRIVATE_KEY}" ]]; then
        echo "Environment variable PRIVATE_KEY not exported"
        exit
    fi

    if [[ -z "${NETWORK}" ]]; then
        echo "Environment variable NETWORK not exported"
        exit
    fi
}

function _getContractAddress() {
    echo -n "Enter the contract address: "
    read contractAddress

    export CONTRACT_ADDRESS=${contractAddress}
}

function _getTokenDetails() {
    echo -n "Enter the token name: "
    read tokenName

    export TOKEN_NAME=${tokenName}

    echo -n "Enter the token ticker: "
    read tokenTicker

    export TOKEN_TICKER=${tokenTicker}

    echo -n "Enter the token decimals: "
    read tokenDecimals

    export TOKEN_DECIMALS=${tokenDecimals}
}

function _getWrappedTokenDetails() {
    echo -n "Enter the backing token contract address: "
    read tokenBackingContract

    export WRAPPED_TOKEN_BACKING_CONTRACT=${tokenBackingContract}
}
