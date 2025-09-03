const ethers = require('ethers');
const rpcProvider = new ethers.JsonRpcProvider("https://rpc.tst.ecredits.com");
const wallet = new ethers.Wallet("0xf66fdc15278cc08793db75d84f35b5efd9845aa214c595c0f767ffee72d0d189", rpcProvider);

async function checkFunds(address){
    let balance = await rpcProvider.getBalance(address);
    return balance;
}

async function main(){
    let currentBalance = await checkFunds(wallet.address)
    console.log(wallet.address);
    console.log(currentBalance);
    let ether = ethers.formatEther(currentBalance);
    console.log(ether);
    /*let feeData = await rpcProvider.getFeeData(); 
    console.log( feeData );

    let feeAmount = feeData.gasPrice * BigInt(21000);
    console.log(feeAmount);
    let transactionAmount = currentBalance - feeAmount;
    console.log(transactionAmount);
    
    const tx = {
        to: "0x3Ba144a04CB7f00827092668c2BBe723D025dE9d",
        value: transactionAmount,
        gasPrice: feeData.gasPrice,
        gasLimit: '21000'
    };
    
    /*let estimatedGas = await rpcProvider.estimateGas(tx);
    console.log(estimatedGas);*/

    /*wallet.sendTransaction(tx).then((txResponse) => {
        console.log(`Transaction hash: ${txResponse.hash}`)
    });*/
}

main();