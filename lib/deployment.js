var { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
var helpers = require("../lib/helpers.js");
var role = require("./roles.js");

var TokenContract = artifacts.require('FundamentaToken');
var LiquidityMiningContract = artifacts.require('LiquidityMining');
var MockAssetContract = artifacts.require('MockAsset');

exports.token = async (creator) => {
    var token = await TokenContract.new({ from: creator });

    await token.grantRole(role.admin, creator, { from: creator });
    await token.setPaused(false);

    await token.grantRole(role.mintTo, creator, { from: creator });
    await token.grantRole(role.burnFrom, creator, { from: creator });

    return token;
}

exports.liquidityMining = async (creator) => {
    var liquidityMining = await LiquidityMiningContract.new({ from: creator });

    await liquidityMining.grantRole(role.admin, creator, { from: creator});
    await liquidityMining.setPaused(false);
    await liquidityMining.paused();

    return liquidityMining;
}
