const BigDecimal = require('js-big-decimal');
const { exec } = require('child_process');

exports.to8bitHex = (value) => { return ('00' + value.toString(16)).slice(-2); }

exports.to16bitHex = (value) => { return ('0000' + value.toString(16)).slice(-4); }

exports.to32bitHex = (value) => { return ('00000000' + value.toString(16)).slice(-8); }

exports.to64bitHex = (value) => { return ('0000000000000000' + value.toString(16)).slice(-16); }

exports.bin2hex = (arr) => {
    var hex = "";
    for (var i = 0; i < arr.length; i++)
        hex += this.to8bitHex(arr[i]);

    return hex;
}

exports.toAtomicUnits = (value, decimals) => {
    if (isNaN(decimals)) decimals = 18;
    var bd = new BigDecimal(value);
    var exp = new BigDecimal(Math.pow(10, decimals));
    bd = bd.multiply(exp);
    return BigInt(bd.getValue());
}

exports.fromAtomicUnits = (value, decimals) => {
    if (isNaN(decimals)) decimals = 18;
    return new BigDecimal(value).divide(new BigDecimal(Math.pow(10, decimals)));
}

exports.toAtomicUnitsHex = (value, decimals) => {
    if (isNaN(decimals)) decimals = 18;
    return this.toAtomicUnits(value, decimals).toString(16).padStart(64, '0');
}

exports.createNonce = (sender) => {
    var address = sender.slice(-40);
    var timestamp = this.to32bitHex(Date.now());
    var array = new Uint8Array(8);
    var hex = this.bin2hex(array);
    return (timestamp + address + hex);
}

exports.generateTxData = async (sender, sourceNetwork, destNetwork, token, amount) => {
    var amt = this.toAtomicUnitsHex(amount);

    var srcNet = this.to32bitHex(sourceNetwork);
    var dstNet = this.to32bitHex(destNetwork);
    var tok = this.to32bitHex(token);
    var add = sender.address.slice(-40).toString().padStart(64, 0);

    var nonce = this.createNonce(sender.address);

    var transactionData = '0x' + amt + srcNet + dstNet + tok + add + nonce;

    return {
        amount: this.fromAtomicUnits(BigInt('0x' + amt)),
        amountHex: amt,
        sourceNetwork: Number(srcNet),
        destinationNetwork: Number(dstNet),
        token: Number(tok),
        sender: add,
        nonce: BigInt('0x' + nonce).toString(),
        nonceHex: nonce,

        data: transactionData,
    };
}

exports.hashAndSign = async (data, account) => {
    var proc = './tools/SignerTool ' + data + ' ' + account.privateKey;

    return new Promise((resolved, rejected) => {
        exec(proc, (error, stdout, stderr) => {
            if (error) {
                console.log(`error: ${error.message}`);
                rejected(error);
                return;
            }
            if (stderr) {
                console.log(`stderr: ${stderr}`);
                return;
            }

            resolved(JSON.parse(stdout));
        });
    });
};  

exports.mineBlock = async () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err); }
            const newBlockHash = web3.eth.getBlock('latest').hash;

            return resolve(newBlockHash)
        });
    });
}

exports.parseTotalFees = (fees) => {
    return {
        accumulatedFee: this.fromAtomicUnits(fees[0]),
        burnedFmta: this.fromAtomicUnits(fees[1])
    };
}

exports.parseTotalFeesToNumber = (fees) => {
    return {
        accumulatedFee: Number(this.fromAtomicUnits(fees[0]).value),
        burnedFmta: Number(this.fromAtomicUnits(fees[1]).value)
    };
}

exports.parseWrappedTokenFees = (fees) => {
    return {
        fmtaWrapFee: this.fromAtomicUnits(fees[0]),
        fmtaUnwrapFee: this.fromAtomicUnits(fees[1]),
        wrapFee: fees[2],
        unwrapFee: fees[3]
    };
}

exports.parseWrappedTokenFeesToNumber = (fees) => {
    return {
        fmtaWrapFee: Number(this.fromAtomicUnits(fees[0]).value),
        fmtaUnwrapFee: Number(this.fromAtomicUnits(fees[1]).value),
        wrapFee: Number(fees[2]),
        unwrapFee: Number(fees[3])
    };
}
