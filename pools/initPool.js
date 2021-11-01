import "@nomiclabs/hardhat-ethers";

// Addresses are the same on all networks

const VAULT = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';

const WEIGHTED_POOL_FACTORY = '0x8E9aa87E45e92bad84D5F8DD1bff34Fb92637dE9';
const ORACLE_POOL_FACTORY = '0xA5bf2ddF098bb0Ef6d120C98217dD6B141c74EE0';
const STABLE_POOL_FACTORY = '0x791F9fD8CFa2Ea408322e172af10186b2D73baBD';

const DELEGATE_OWNER = '0xBA1BA1ba1BA1bA1bA1Ba1BA1ba1BA1bA1ba1ba1B';

// Mainnet addresses; adjust for testnets

const MKR = '0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2';
const WETH = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
const USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7';

const tokens = [MKR, WETH, USDT];

const NAME = 'Three-token Test Pool';
const SYMBOL = '70MKR-15WETH-15USDT';
const swapFeePercentage = 0.5e16; // 0.5%

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const factory = await ethers.getContractAt('WeightedPoolFactory', WEIGHTED_POOL_FACTORY);
const vault = await ethers.getContractAt('Vault', VAULT);

// ZERO_ADDRESS owner means fixed swap fees
// DELEGATE_OWNER grants permission to governance for dynamic fee management
// Any other address lets that address directly set the fees
const tx = await factory.create(NAME, SYMBOL, tokens, weights,
  swapFeePercentage, ZERO_ADDRESS);
const receipt = await tx.wait();

// We need to get the new pool address out of the PoolCreated event
// (Or just grab it from Etherscan)
const events = receipt.events.filter((e) => e.event === 'PoolCreated');
const poolAddress = events[0].args.pool;

// We're going to need the PoolId later, so ask the contract for it
const pool = await ethers.getContractAt('WeightedPool', poolAddress);
const poolId = await pool.getPoolId();


// Tokens must be in the same order
// Values must be decimal-normalized! (USDT has 6 decimals)
const initialBalances = [16.667e18, 3.5714e18, 7500e6];
const JOIN_KIND_INIT = 0;

// Construct magic userData
const initUserData =
  ethers.utils.defaultAbiCoder.encode(['uint256', 'uint256[]'],
    [JOIN_KIND_INIT, initialBalances]);
const joinPoolRequest = {
  assets: tokens,
  maxAmountsIn: initialBalances,
  userData: initUserData,
  fromInternalBalance: false
}

// Caller is "you". joinPool takes a sender (source of initialBalances)
// And a receiver (where BPT are sent). Normally, both are the caller.
// If you have a User Balance of any of these tokens, you can set
// fromInternalBalance to true, and fund a pool with no token transfers
// (well, except for the BPT out)

// Need to approve the Vault to transfer the tokens!
// Can do through Etherscan, or programmatically
const mkr = await ethers.getContractAt('ERC20', MKR);
await mkr.approve(VAULT, 17e18);
// ... same for other tokens

// joins and exits are done on the Vault, not the pool
const tx = await vault.joinPool(poolId, caller, caller, joinPoolRequest);
// You can wait for it like this, or just print the tx hash and monitor
const receipt = await tx.wait();

