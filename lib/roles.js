exports.admin = "0xae6c2fc584631af4c9385b8a55683f1a75c813747e27efef5afece31c6b230d3";
exports.mint = "0x8c66330d9d4f6aba064f25ef2a307366ea6d917616f44c075aa60fa15e5cb1cb";
exports.mintTo = "0x7d800f56a05adcb6245df540492a560d0e668aac15ee6c7dd40668064913da33";
exports.burn = "0x9edfad36e7d4d9da54b4f78f22bf97cb5b58bb7998294a4288da41c15c647c45";
exports.burnFrom = "0xc8a3befa5973ff6e159afc769978d92f26bae29c51a73d11c9112a05b68d25e6";
exports.deposit = "0x587067af7acf278357651084bc3b5223d9fae81a768c4f25238b853ff2756ada";
exports.staking = "0x7308377bbcfee4c643b62e55a600f0c1ee294f1d8949667b05bfef816828e284";
exports.bridgeTx = "0x8c07325f686988417936836fa712928a5e8319c01e2032f132d3f5bc3de91a47";

exports.roles = new Map([
    ["admin", this.admin],
    ["mint", this.mint],
    ["mintTo", this.mintTo],
    ["burn", this.burn],
    ["burnFrom", this.burnFrom],
    ["deposit", this.deposit],
    ["staking", this.staking],
    ["bridgeTx", this.bridgeTx]
]);
