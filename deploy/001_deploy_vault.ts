import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import {expandDecimals} from "../test/ts/shared/utilities";
import {BigNumber} from "ethers";

export const SECOND = 1;
export const MINUTE = SECOND * 60;
export const HOUR = MINUTE * 60;
export const DAY = HOUR * 24;
export const WEEK = DAY * 7;
export const MONTH = DAY * 30;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const {deployments, getNamedAccounts} = hre;
	const {deploy, execute} = deployments;
	const {deployer, governance, weth} = await getNamedAccounts();
	console.log('deployer', deployer)
	console.log('governance', governance)

	const authorizer = await deploy("Authorizer", {
		contract: "Authorizer",
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [governance],
		log: true,
	});
	// console.log(weth)
	//
	const NileRiverRouter = await deploy("NileRiverRouter", {
		contract: "NileRiverRouter",
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [authorizer.address, weth, 3* MONTH, MONTH],
		log: true,
	});
	const NileRiverHelpers = await deploy("NileRiverHelpers", {
		contract: "NileRiverHelpers",
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [NileRiverRouter.address],
		log: true,
	});
	//
	const StablePoolFactory = await deploy("StablePoolFactory", {
		contract: "StablePoolFactory",
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [NileRiverRouter.address],
		log: true,
	});
	//
	const WeightedPoolFactory = await deploy("WeightedPoolFactory", {
		contract: "WeightedPoolFactory",
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [NileRiverRouter.address],
		log: true,
	});

	// const Multicall = await deploy("Multicall", {
	// 	contract: "Multicall",
	// 	skipIfAlreadyDeployed: false,
	// 	from: deployer,
	// 	args: [],
	// 	log: true,
	// });


};

export default func;
func.tags = ["vault"];
