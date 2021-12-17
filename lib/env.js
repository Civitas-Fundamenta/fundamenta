module.exports = {
    privateKey: process.env['PRIVATE_KEY'],
    network: process.env['NETWORK'],
    
    fmtaContract: '0xAa9D866666C2A3748d6B23Ff69E63E52f08d9AB4',
    ganacheChainId: 1337,
    deploymentFile: 'deployments/' + process.env['NETWORK'] + '.json',
    traderDeploymentFile: 'deployments/trader.' + process.env['NETWORK'] + '.json'
}

module.exports.arg = (index) => {
    return process.argv[index + 6];
}
