const HDWalletProvider = require("@truffle/hdwallet-provider");
var env = require('./lib/env.js');

module.exports = {
    //contracts_build_directory: "./node_modules/@openzeppelin/contracts/build/contracts",
    networks: {
        development: {
            host: "127.0.0.1",
            port: 8545,
            network_id: "*"
        },
        ganache: {
            host: "127.0.0.1",
            port: 8545,
            network_id: "*"
        },
        ethereum: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://mainnet.infura.io/v3/9354d2b6c5ee45c2a4036efd7b617783'),
            network_id: 1
        },
        binance: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://bsc-dataseed.binance.org/'),
            network_id: 56
        },
        polygon: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://nameless-spring-thunder.matic.quiknode.pro/'),
            network_id: 137
        },
        cronos: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://evm-cronos.crypto.org'),
            network_id: 25
        },
        rinkeby: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://rinkeby.infura.io/v3/9354d2b6c5ee45c2a4036efd7b617783'),
            network_id: 4
        },
        goerli: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://goerli.infura.io/v3/9354d2b6c5ee45c2a4036efd7b617783'),
            network_id: 5
        },
        mumbai: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://polygon-mumbai.infura.io/v3/9354d2b6c5ee45c2a4036efd7b617783'),
            network_id: 80001
        },
        cassini: {
            provider: () => new HDWalletProvider(env.privateKey, 'https://cassini.crypto.org:8545/'),
            network_id: 339
        }
    },
    compilers: {
        solc: {
            version: "0.8.9",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        }
    },
        plugins: [
            'truffle-plugin-verify'
        ],
        api_keys: {
            etherscan: 'DSPIB99YWA86DB16VVZT3KPKCET9V6YUEH',
            bscscan: 'SMGQYIQK2JPXWTDUE8ZMHWTE6XE9E2B52P',
            polygonscan: '4WTN7GV1XZA42A4RXHQUVFXYB67GWCUYBG'
        }
    }
