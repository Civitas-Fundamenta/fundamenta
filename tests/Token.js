const { master, account1, account2, account3 } = require('../lib/accounts.js');
const role = require('../lib/roles.js');
const env = require('../lib/env.js');
const helpers = require('../lib/helpers.js');
const deploy = require('../lib/deployment.js');

contract('Test', () => {
    var deployed;

    before(async function () {

        var contract = artifacts.require('FundamentaToken');

        deployed = await contract.new();
    });

    it('Check Balance', async function () {
        
        //mint some tokens to account1
        await deployed.mintTo(account1.address, helpers.toAtomicUnits(10000), { from: master.address });

        //get the balance of account1
        var balance = await deployed.balanceOf(account1.address);

        //fromAtomicUnits is a BigDecimal. use .value to get a nicely formatted value
        console.log("Balance:", helpers.fromAtomicUnits(balance).value)
    });
});