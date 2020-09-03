module.exports = {
  migrations_directory: "./migrations",
 
   networks: {
    development: {
      host: "localhost",
      port: 7545,
      network_id: "*" // Match any network id
    },
  },
   compilers: {
    solc: {
      version: "0.6.6",
  }
 }
};
