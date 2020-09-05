const FMTAToken = artifacts.require("FMTAToken");

module.exports = function(deployer) {
  /* Deploy your contract here with the following command */
  // deployer.deploy(YourContract);
  deployer.deploy(FMTAToken);
};
