import {config as dotEnvConfig} from 'dotenv';

dotEnvConfig();
import {HardhatUserConfig} from 'hardhat/types';
import 'hardhat-typechain';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-contract-sizer';
import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-etherscan';

import {HardhatNetworkAccountsUserConfig} from 'hardhat/types/config';

const INFURA_API_KEY = process.env.INFURA_API_KEY as string;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY as string;
const MNEMONIC = process.env.MNEMONIC as string;
const accounts: HardhatNetworkAccountsUserConfig = {
    mnemonic: MNEMONIC ?? 'test test test test test test test test test test test junk'
}
const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    namedAccounts: {
        deployer: 2,
        bob: 1,
        weth: {
            bsctestnet: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            bsc: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            polygon: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
            fantom: '0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83',
            moonriver: '0x98878B06940aE243284CA214f92Bb71a2b032B8A',
        },
        governance: {
            hardhat: 1,
            local: 1,
            bsc: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            polygon: '0x82D733C32Bb3b760Ca50B83B75642b668E9B2EBD',
            fantom: '0x3499044221a90D89fa086BD938ab0ab958976F7b',
            moonriver: '0xEF6968F22fd0AfF6755df5d0864AAB5c128DBbb4',
            bsctestnet: 1,
        },
        proxyAdmin: {
            hardhat: 2,
            local: 2,
            bsc: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            polygon: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            bsctestnet: 2,
        },
        uniRouter: {
            hardhat: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            local: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            bsc: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            polygon: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
            bsctestnet: '0x16cEE236b853fBeb01D5f2e51399D753B820ff91',
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    solidity: {
        compilers: [
            {
                version: '0.8.6', settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.7.1', settings: {
                    optimizer: {
                        enabled: true,
                        runs: 9999,
                    },
                },
            },
            {
                version: '0.6.12', settings: {
                    optimizer: {
                        enabled: true,
                        runs: 9999,
                    },
                },
            },
        ],
        overrides: {
            "contracts/weighted-pools/WeightedPool2TokensFactory.sol": {
                version: '0.7.1',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            "contracts/NileRiverRouter.sol": {
                version: '0.7.1',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999,
                    },
                },
            },
            "contracts/Multicall.sol": {
                version: '0.6.12',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999,
                    },
                },
            }
        }
    },

    networks: {
        hardhat: {
            tags: process.env.DEFAULT_TAG ? process.env.DEFAULT_TAG.split(',') : ['local'],
            live: false,
            saveDeployments: false,
            allowUnlimitedContractSize: true,
            chainId: 1,
            accounts,
        },
        localhost: {
            tags: ['local'],
            live: false,
            saveDeployments: false,
            url: 'http://localhost:8545',
            accounts,
            timeout: 60000,
        },
        rinkeby: {
            tags: ['local', 'staging'],
            live: true,
            saveDeployments: true,
            url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
            accounts,
        },
        kovan: {
            tags: ['local', 'staging'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
        },
        bsctestnet: {
            tags: ['local', 'staging'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://data-seed-prebsc-1-s2.binance.org:8545`,
        },
        bsc: {
            tags: ['production'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://bsc-dataseed.binance.org/`,
        },
        polygon: {
            tags: ['production'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://rpc-mainnet.maticvigil.com/`,
        },
        fantom: {
            tags: ['production'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://rpc.ftm.tools/`,
        },
        moonriver: {
            tags: ['production'],
            live: true,
            saveDeployments: true,
            accounts,
            loggingEnabled: true,
            url: `https://rpc.moonriver.moonbeam.network`,
        },
        ganache: {
            tags: ['local'],
            live: true,
            saveDeployments: false,
            accounts,
            url: 'http://127.0.0.1:8555', // Coverage launches its own ganache-cli client
        },
        coverage: {
            tags: ['local'],
            live: false,
            saveDeployments: false,
            accounts,
            url: 'http://127.0.0.1:8555', // Coverage launches its own ganache-cli client
        },
    },
    typechain: {
        outDir: 'typechain',
        target: 'ethers-v5',
    },
    paths: {
        sources: './contracts',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts',
    },
    external: {
        contracts: [{
            artifacts : "node_modules/@openzeppelin/upgrades/build/contracts"
        }]
    },
    mocha: {
        timeout: 200000
    },

    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    }
};

export default config;
