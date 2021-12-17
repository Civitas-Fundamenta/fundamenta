var { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
var helpers = require("../lib/helpers.js");
var role = require("./roles.js");

var TokenContract = artifacts.require('FundamentaToken');

exports.token = async (ticker, creator) => {
    var token = await TokenContract.new(ticker, ticker, 18, { from: creator });

    await token.grantRole(role.admin, creator, { from: creator });
    await token.setPaused(false);

    await token.grantRole(role.mintTo, creator, { from: creator });
    await token.grantRole(role.burnFrom, creator, { from: creator });

    return token;
}

