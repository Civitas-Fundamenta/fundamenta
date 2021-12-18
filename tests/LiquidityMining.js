var { master, account1, account2 } = require('../lib/accounts.js');
var helpers = require('../lib/helpers.js');
var deploy = require('../lib/deployment.js');

contract('LiquidityMiningTest', () => {
    let liquidityMining, fmtaToken;
    
    before(async function () {
        //Not the real FMTA token
        fmtaToken = await deploy.token();

        liquidityMining = await deploy.liquidityMining();

    });

    it('Check Balance', async function () {
        //grant the master address the mintTo role. roles are defined in ../lib/roles.js
        await fmtaToken.grantRole(role.mintTo, master.address, { from: master.address });

        //This token contract can't mint while paused. So unpause it
        await fmtaToken.setPaused(false, { from: master.address });
        
        //mint some tokens to account1
        await fmtaToken.mintTo(account1.address, helpers.toAtomicUnits(10000), { from: master.address });

        //get the balance of account1
        var balance = await deployed.balanceOf(account1.address);

        //fromAtomicUnits is a BigDecimal. use .value to get a nicely formatted value
        console.log("Balance:", helpers.fromAtomicUnits(balance).value)
    });
});
