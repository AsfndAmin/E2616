const vRent = artifacts.require("vRent");
const Payment = artifacts.require("payment");


module.exports = async function (deployer, network) {
  const owner = "0x51Df6E93d5d71B0bE6894A5FFCBa322702066C49";
  const beneficiary = "0x51Df6E93d5d71B0bE6894A5FFCBa322702066C49";


  deployer.deploy(Payment, owner).then(async () => {
    // get JS instance of deployed contract
    const payment = await Payment.deployed();
    // pass its address as argument for vRent's constructor

    var WETH = "";
    var USDC = "";
    switch (network) {
      case 'mainnet':
        WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" // mainnet ethereum
        USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" // mainnet ethereum

        break;

      case 'rinkeby':
        WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab" // rinkeby weth
        USDC = "0xeb8f08a975Ab53E34D8a0330E0D34de942C95926" // rinkeby USDC
        break;

      case 'bsc':
        USDC = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
        WETH = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
        break;

      case 'bscTestnet':
        break;

      case 'matic':
        WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619" // polygon mainnet
        USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174" // polygon mainnet
        break;

      case 'mumbai':
        WETH = "0x062f24cb618e6ba873EC1C85FD08B8D2Ee9bF23e" // mumbai weth
        USDC = "0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747" // mumbai
        break;
    }


    //set payment method
    payment.setPaymentToken(1, USDC)
    payment.setPaymentToken(2, WETH);
    await deployer.deploy(vRent, payment.address, beneficiary, owner).then(async () => {

      //console.log('REACT_APP_' + network.toUpperCase()+'_WETH=' + WETH);
      //console.log('REACT_APP_' + network.toUpperCase()+'_USDC=' + USDC);
      console.log('REACT_APP_'+ network.toUpperCase() +'_PAYMENT_CONTRACT_ADDRESS=' + payment.address);
      console.log('REACT_APP_'+ network.toUpperCase() +'_RENT_CONTRACT_ADDRESS=' + vRent.address);

        configstr =  network + ':\n{\n contract_address: \''+  vRent.address + '\',\n'+ 'payment_address:'+'\''+ payment.address + '\'\n}'; 

        console.log(configstr.replace(/ /gm,''));

    })
  });
};
