var { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
var helpers = require("../lib/helpers.js");
var role = require("./roles.js");

var TokenContract = artifacts.require('FundamentaToken');
var WrappedTokenContract = artifacts.require('FundamentaWrappedToken');
var BridgeContract = artifacts.require('FundamentaBridge');

exports.token = async (ticker, creator) => {
    var token = await TokenContract.new(ticker, ticker, 18, { from: creator });

    await token.grantRole(role.admin, creator, { from: creator });
    await token.setPaused(false);

    await token.grantRole(role.mintTo, creator, { from: creator });
    await token.grantRole(role.burnFrom, creator, { from: creator });

    return token;
}

exports.wrappedToken = async (ticker, backingToken, fmtaToken, creator) => {
    var token = await WrappedTokenContract.new(backingToken.address, ticker, ticker, 18, fmtaToken.address, { from: creator });

    await token.grantRole(role.admin, creator, { from: creator });
    await token.setPaused(false);

    //Need to allow bridge to burn fmta for rees
    await fmtaToken.grantRole(role.mintTo, token.address, { from: creator });
    await fmtaToken.grantRole(role.burnFrom, token.address, { from: creator });

    //note fmta fees are in fmta atomic units
    //await token.setFmtaWrapFee(helpers.toAtomicUnits(5));
    //await token.setFmtaUnwrapFee(helpers.toAtomicUnits(5));

    //system fees are in basis points and not converted to atomic units
    //await token.setWrapFee(100);
    //await token.setUnwrapFee(100);

    //for testing only
    await token.grantRole(role.mintTo, creator, { from: creator });
    await token.grantRole(role.burnFrom, creator, { from: creator });

    return token;
}

exports.bridge = async (creator, id) => {
    var bridge = await BridgeContract.new({ from: creator });
    bridge.initialize(id);

    await bridge.grantRole(role.admin, creator, { from: creator });
    await bridge.setPaused(false);

    return bridge;
}

exports.proxiedBridge = async (creator) => {
    var proxy = await deployProxy(BridgeContract, { from: creator });

    console.log("Proxy Address:", proxy.address);
    
    await proxy.grantRole(role.admin, creator, { from: creator });
    await proxy.setPaused(false);

    return proxy;
}

exports.upgradeProxiedBridge = async (proxy, newImplementation, creator) => {
    return await upgradeProxy(proxy.address, newImplementation, { from: creator });
}