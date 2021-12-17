var validators = require('../lib/validators.js');
var role = require("../lib/roles.js");

exports.registerValidators = async (bridge) => {
    var l = validators.addresses.length;
    for (var i = 0; i < l; i++) {
        var hasRole = await bridge.hasRole(role.deposit, validators.addresses[i]);
        if (!hasRole)
        {
            console.log('Registering validator', validators.addresses[i]);
            await bridge.grantRole(role.deposit, validators.addresses[i]);
        }
        else
            console.log('Validator', validators.addresses[i], 'already registered');
    }
}

exports.token = async (bridge, id, isWrappedToken, token) => {
    var queryResult = await bridge.queryToken(id);

    if (queryResult.token !== '0x0000000000000000000000000000000000000000')
        console.log('Token already registered at index', id);
    else
    {
        console.log('Setting bridge token ' + id + ' to contract ' + token.address);
        await bridge.addToken(id, isWrappedToken, 2, token.address);
        queryResult = await bridge.queryToken(id);
    }

    console.log('Configuring token @', token.address);

    if (isWrappedToken) {
        var hasBridgeTxRole = await token.hasRole(role.bridgeTx, bridge.address);
        if (!hasBridgeTxRole)
        {
            console.log("Assigning wrapped token BRIDGE_TX role to bridge");
            await token.grantRole(role.bridgeTx, bridge.address);
        }

        //todo: set mintTo and burnFrom roles on the fmta contract
    }

    var hasMintToRole = await token.hasRole(role.mintTo, bridge.address);
    if (!hasMintToRole)
    {
        console.log("Assigning token MINTTO role to bridge");
        await token.grantRole(role.mintTo, bridge.address);
    }

    var hasBurnFromRole = await token.hasRole(role.burnFrom, bridge.address);
    if (!hasBurnFromRole)
    {
        console.log("Assigning token BURNFROM role to bridge");
        await token.grantRole(role.burnFrom, bridge.address);
    }

    if (!queryResult.canWithdraw)
    {
        console.log("Setting canWithdraw true");
        await bridge.setTokenCanWithdraw(id, true);
    }

    if (!queryResult.canDeposit)
    {
        console.log("Setting canDeposit true");
        await bridge.setTokenCanDeposit(id, true);
    }

    await token.setPaused(false);
}