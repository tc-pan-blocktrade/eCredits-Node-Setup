const ethers = require('ethers');
const { parse } = require("csv-parse");
const fs = require("fs");
let provider
let depositData
let transactionDataPath

async function getPubkey(txHash){
    let pubkey = "";
    let trx = await provider.getTransaction(txHash);
    
    let abi =["bytes","bytes","bytes","bytes32"];
    dataslice = ethers.dataSlice(trx.data,4,);
    let output = ethers.AbiCoder.defaultAbiCoder().decode(abi,dataslice);
    pubkey = output[0];
    
    return pubkey;
}

async function main(){
    let successfullTransactionsCounter = 0;
    let transactionHashes = {};
    let stakedKeys = {};
    let numberOfStakedKeys = 0;
    let nubmerOfNotStakedKeys = 0;
    let jsonObject = {};

    await fs.createReadStream(transactionDataPath)
    .pipe(parse({ delimite: ",", from_line:2 }))
    .on("data", function (row){
        //We filter out the contract deployment and failed transactions.
        if(row[9] == "ok" && row[7] > 0){
            successfullTransactionsCounter+=1;
            transactionHashes[row[0]] = row[2];
        }
    })
    .on("close", async function() {
        console.log(`+ ${Object.keys(transactionHashes).length} transactions loaded. Processing hashes.`);
        let hashes = Object.keys(transactionHashes);
        for (hash of hashes) {
            let key = await getPubkey(hash);
            stakedKeys[key] = {hash: hash, unixtimestamp: transactionHashes[hash]};
        };
        //console.log(stakedKeys);
        let staked_keys_data = JSON.stringify(stakedKeys);
        fs.writeFile("staked_keys.json",staked_keys_data, (error)=> {
            if(error){
                console.error(error);
                throw error;
            }
            console.log("generated staked keys data log file.");
        });
        for(record of depositData){
            if(`0x${record["pubkey"]}` in stakedKeys){
                numberOfStakedKeys+=1;
                stakedKey = record["pubkey"];
                stakedHash = stakedKeys[`0x${stakedKey}`]["hash"];
                jsonObject[stakedKey] = { state: "mined", hash: stakedHash };
            }
            else {
                nubmerOfNotStakedKeys+=1;
                console.log(`Key 0x${record["pubkey"]} is not staked.`);
                jsonObject[record["pubkey"]] = { state: "error", message: "Key not found in transactions."};
            }
        }
        console.log(`Total staked keys in transactions file: ${Object.keys(stakedKeys).length}`);
        console.log(`Staked keys from deposit data file: ${numberOfStakedKeys}`);
        console.log(`Not staked keys from deposit data file: ${nubmerOfNotStakedKeys}`);
        jsonData = JSON.stringify(jsonObject);
        fs.writeFile("generated_depoit_log.json", jsonData, (error) => {
            if(error){
                console.error(error);
                throw error;
            }
            console.log("generated deposit data log file.");

        });
    });
}
//checkKeys.js testnet depositDataFilePath transactions.csv
if (process.argv.length == 5) {
    network = process.argv[2]
    if (network == "mainnet") {
        console.log("Running key check for MAINNET!");
        rpcUrl = 'https://rpc.ecredits.com';
    }
    else if (network == "testnet") {
        console.log("Running key check for TESTNET!");
        rpcUrl = 'https://rpc.tst.esync.network';
    }
    else {
        console.log("Unknown network configuration.")
        exit;
    }
    provider = new ethers.JsonRpcProvider(rpcUrl);

    depositDataPath = process.argv[3]
    depositData = require(depositDataPath)

    transactionDataPath = process.argv[4]
    main();
}
else {
    console.log("Number of Arguments not matching.")
    console.log("Please call the script like the following example:")
    console.log("node checkKeys.js <networkname> <path_to_deposit_data_file> <path_to_transactions_csv>")
}