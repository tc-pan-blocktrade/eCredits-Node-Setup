#!/usr/bin/env node
const { spawn } = require('child_process');
const ethers = require('ethers');
const readlinesync = require('readline-sync');
const fs = require('fs');
const path = require('path');
const OUTPUT_DIR = "/gened";
let depositContractAddress = "";
let rpcUrl = "";

let stakingCliEcsFlag = "";
const timestamp = new Date().toISOString();
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

function create_mnemonic() {
    const entropy = ethers.randomBytes(32);
    const mnemonic = ethers.Mnemonic.fromEntropy(entropy);
    return mnemonic.phrase;
}

async function createWallet(password) {
    phrase = create_mnemonic();
    console.log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    console.log("!!! Please store the following seed phrase for the temporaray wallet in a secure location as you'll need it to recover this account if you've lost the password! !!!");
    console.log("!!! It is used to create the temporary account that will be used to stake for your keys!                                                                             !!!");
    console.log("--------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    console.log(phrase);
    console.log("--------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    output_directory = OUTPUT_DIR;
    keystore_password = password;
    mnemonic = ethers.Mnemonic.fromPhrase(phrase);
    var walletPath = "m/44'/60'/0'/0/0"
    var wallet = ethers.HDNodeWallet.fromMnemonic(mnemonic, walletPath);

    var keystore = await wallet.encrypt(keystore_password)
        .catch(error => {
            console.log('+', 'Keystore creation failed.');
        });
    var keystoreFileName = `keystore_${wallet.address}`;
    var outputPath = `${output_directory}/${keystoreFileName}.json`;

    fs.writeFile(outputPath, keystore, 'utf-8', function (error) {
        if (error === null) {
            console.log(`+ The keystore file of the temporary account has been stored under ${outputPath}`);
        } else {
            console.log(`- Error on writing keystore file to ${outputPath}`);
            console.log(error);
        }
    });
    return wallet;
}

function getDepositDataPath() {
    var dir = OUTPUT_DIR + "/validator_keys"
    var pattern = 'deposit_data-.*\.json';
    let result = [];
    const regex = new RegExp(pattern);
    fs.readdirSync(dir).forEach((file) => {
        const filePath = path.join(dir, file);
        if (fs.statSync(filePath).isDirectory()) {
            result = result.concat(findFile(filePath, pattern));
        } else if (regex.test(file)) {
            result.push(filePath);
        }
    });
    return result;
}

function delay(duration) {
    return new Promise((resolve) => {
        setTimeout(resolve, duration);
    });
}

async function checkFunds(address, threshold) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    let balance = await provider.getBalance(address)
        .catch(error => {
            console.log('+', 'Get Balance failed.');
        });
    let weiThreshold = BigInt(threshold) * BigInt(1000000000000000000)
    if (balance >= weiThreshold) {
        console.log();
        console.log("+ Sufficent funds are available.");
        return true;
    }
    return false;
}

async function depositStake(wallet, depositDataFile, number_of_validators, depositDataLog) {
    const DEPOSIT_AMOUNT = 256;
    console.log("------------------------------------------------------------- Preparing staking transactions -----------------------------------------------------------------------");
    console.log();
    console.log(`+ Using deposit data file at ${depositDataFile}`);
    console.log(`+ The temporary wallet ${wallet.address}, that has been created earlier in this process, will be used as source for the staking transaction.`);
    required_ECS = number_of_validators * DEPOSIT_AMOUNT;
    let requiredGasFee = 1;
    const totalRequiredECS = required_ECS + requiredGasFee;
    console.log(`+ In order to stake for ${number_of_validators} validators, you need to deposit ${totalRequiredECS} ECS (${required_ECS} + ${requiredGasFee} gas fee) to this account.`)
    let sufficentFunds = readlinesync.question('> Please confirm that the wallet has sufficient funds before you continue! [N/y]: ');

    if (sufficentFunds === 'Y' || sufficentFunds === 'y') {
        console.log("+ Verifying funds");
        let repeatCounter = 0;
        let sufficientFunds = await checkFunds(wallet.address, totalRequiredECS)
            .catch(error => {
                console.log('+', 'Check funds failed.');
            });
        while (!sufficientFunds) {
            if (repeatCounter > 5) {
                break;
            }
            process.stdout.write("*");
            sufficientFunds = await checkFunds(wallet.address, totalRequiredECS)
                .catch(error => {
                    console.log('+', 'Check funds failed.');
                });
            await delay(5000);
            repeatCounter += 1;
        }
    }
    console.log("");
    if (await checkFunds(wallet.address, totalRequiredECS)
        .catch(error => {
                console.log('+', 'Check funds failed.');
            }) 
        && (sufficentFunds ==="Y" || sufficentFunds ==="y")) {
        console.log("+ Start sending staking transactions.")
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        const depositContractJSON = JSON.parse(fs.readFileSync('/setup/deposit_contract.json'));

        let stakingWallet = new ethers.Wallet(wallet.privateKey, provider);
        let depositContract = new ethers.Contract(depositContractAddress, depositContractJSON.abi, stakingWallet);

        const depositData = JSON.parse(fs.readFileSync(depositDataFile));
        
        const log_stream = fs.createWriteStream(`${OUTPUT_DIR}/process_log_${timestamp}.json`);
        log_stream.write(`{\n`)

        console.log('+ Depositing for', depositData.length, 'validators.')
        let transactionStatis = {};
        let pubkeyStatis = {};
        let successfullAccounts = 0;
        let failedAccounts = 0;
        let processedAccount = 0;
        let lastTX;
        let processRecord = true;
        let sufficient_funds = true;
        let countTillWait = 0;
        for (let i in depositData) {
            const {
                pubkey,
                withdrawal_credentials,
                signature,
                deposit_data_root,
            } = depositData[i];
            processRecord = true;
            if (typeof depositDataLog != 'undefined') {
                if (pubkey in depositDataLog && depositDataLog[pubkey].state == "mined") {
                    processedAccount += 1;
                    successfullAccounts += 1;
                    processRecord = false;
                    pubkeyStatis[pubkey] = { state: depositDataLog[pubkey].state, hash: depositDataLog[pubkey].hash };
                    log_stream.write(`"${pubkey}": {"state": "${depositDataLog[pubkey].state}", "hash": "${depositDataLog[pubkey].hash}"},\n`);
                    console.log(`+ Account ${pubkey} skipped.`);
                    
                }
            }
            if (!sufficient_funds) {
                processRecord = false;
                failedAccounts += 1;
                pubkeyStatis[pubkey] = { state: "error", message: "Skipped due to insufficient funds or errors." };
                log_stream.write(`"${pubkey}": {"state": "error", "message": "Skipped due to insufficient funds or errors."},\n`);
                console.log(`+ Account ${pubkey} skipped, insufficient funds or errors.`);
            }
            if (processRecord) {
                countTillWait+=1;
                if(countTillWait > 10){
                    countTillWait=0;
                    await sleep(10000);
                }
                processedAccount += 1;
                pubkeyStatis[pubkey] = { state: "pending" };
                console.log('+', 'depositing to', pubkey);
                let hasError = false;
                let error_message = '';
                let tx = await depositContract.deposit(
                    '0x' + pubkey,
                    '0x' + withdrawal_credentials,
                    '0x' + signature,
                    '0x' + deposit_data_root,
                    {
                        value: ethers.parseUnits(DEPOSIT_AMOUNT.toString(), "ether"),
                        gasPrice: '20000000000',
                        gasLimit: '200000'
                    })
                    .catch(error => {
                        pubkeyStatis[pubkey] = { state: "error", message: error };
                        log_stream.write(`"${pubkey}": {"state": "error", "message": "${error}"},\n`);   
                        console.log('+', 'Insufficient funds.');
                        sufficient_funds = false;                   
                        hasError = true;
                    });
                console.log('+', 'Deposit sent');
                if (!hasError) {
                    pubkeyStatis[pubkey] = { state: "sent", hash: tx.hash };
                    transactionStatis[tx.hash] = { hash: tx.hash, pubkey: pubkey, state: "sent" };
                    log_stream.write(`"${pubkey}": {"state": "sent", "hash": "${tx.hash}"}\n}`);
                    if (depositData.length == processedAccount) {
                        console.log("Last key processed, waiting for last transaction to be finished.");
                        let finalResult = await tx.wait();
                        if (finalResult.status == 1) {
                            successfullAccounts += 1;
                            transactionStatis[finalResult.hash]["state"] = "mined";
                            pubkeyStatis[transactionStatis[finalResult.hash].pubkey]["state"] = "mined";
                            log_stream.write(`"${transactionStatis[finalResult.hash].pubkey}": {"state": "mined", "hash": "${finalResult.hash}"}`);
                        } else {
                            failedAccounts += 1;
                            pubkeyStatis[pubkey] = { state: "error", message: "Receipe return status != 1." };
                            log_stream.write(`"${pubkey}": {"state": "error", "message": "Receipe return status != 1."}\n}`);
                        }
                    }
                    else {
                        tx.wait()
                            .then((successResult) => {
                                if (successResult.status == 1) {
                                    successfullAccounts += 1;
                                    transactionStatis[successResult.hash]["state"] = "mined";
                                    pubkeyStatis[transactionStatis[successResult.hash].pubkey]["state"] = "mined";
                                    log_stream.write(`"${transactionStatis[successResult.hash].pubkey}": {"state": "mined", "hash": "${successResult.hash}"},\n`);
                                } else {
                                    failedAccounts += 1;
                                    pubkeyStatis[pubkey] = { state: "error", message: "Receipe return status != 1." };
                                    log_stream.write(`"${pubkey}": {"state": "error", "message": "Receipe return status != 1."},\n`);
                                }
                            })
                            .catch(error => {
                                console.log(error);
                            });
                    }
                    lastTX = tx;
                }
                else {
                    failedAccounts += 1;
                    if (typeof lastTX != 'undefined' && depositData.length == processedAccount) {
                        console.log("Waiting for last transaction to be finished.");
                        let finalResult = await lastTX.wait();
                        if (finalResult.status == 1) {
                            successfullAccounts += 1;
                            transactionStatis[finalResult.hash]["state"] = "mined";
                            pubkeyStatis[transactionStatis[finalResult.hash].pubkey]["state"] = "mined";
                            log_stream.write(`"${transactionStatis[finalResult.hash].pubkey}": {"state": "mined", "hash": "${finalResult.hash}"}\n}`);
                            console.log("Staking completed.");
                            console.log(`${successfullAccounts} keys have been staked successfull.`);
                            if (failedAccounts > 0) {
                                console.log(`${failedAccounts} keys gave errors. Please check the deposit_log.json for further details!`);
                            }
                        } else {
                            pubkeyStatis[pubkey] = { state: "error", message: "Receipe return status != 1." };
                            log_stream.write(`"${pubkey}": {"state": "error", "message": "Receipe return status != 1."},\n}`);
                            console.log("Staking completed.");
                            console.log(`${successfullAccounts} keys have been staked successfull.`);
                            if (failedAccounts > 0) {
                                console.log(`${failedAccounts} keys gave errors. Please check the deposit_log.json for further details!`);
                            }
                        }
                    }
                }
            }

        }
        console.log(`${successfullAccounts + failedAccounts} have been processed yet.`)
        let waitcount=0;
        while(depositData.length > successfullAccounts + failedAccounts && waitcount < 6) {
            await sleep(10000);
            waitcount+=1;
            console.log("+ Waiting for transactions to finish.");
        }
        log_stream.write(`}`);
        console.log("+ Staking deposits processed. Writing protocol.")
        let jsonString = JSON.stringify(pubkeyStatis, null, 2);
        fs.writeFile(`${OUTPUT_DIR}/deposit_log.json`, jsonString, (err) => {
            if (err) {
                console.log('- Error writing file', err);
            } else {
                console.log('+ Successfully stored final deposit state in deposit_log.json');
            }
        });
        console.log("Staking completed.");
        console.log(`${successfullAccounts} keys have been staked successfull.`);
        if (failedAccounts > 0) {
            console.log(`${failedAccounts} keys gave errors. Please check the deposit_log.json for further details!`);
        }

    } else {
        console.log("- Without sufficent funds, the staking process will be aborted. You can continue to stake for the keys later.");
    }
}


async function refundRemainingBalance(tempWallet) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    let currentBalance = await provider.getBalance(tempWallet.address)
        .catch(error => {
            console.log('+', 'Check funds failed.');
        });
    etherBalance = ethers.formatEther(currentBalance);

    let feeData = await provider.getFeeData()
        .catch(error => {
            console.log('+', 'Get fee data failed.');
        });
    let feeAmount = feeData.gasPrice * BigInt(21000);
    if (currentBalance > feeAmount) {
        let refund = readlinesync.question(`> There is a remaining balance of ${etherBalance} ECS on the temporary account. Should it be refunded to an account of your choice? [Y/n] `);
        if (refund === 'Y' || refund === 'y' || refund ==='') {
            let refundAccount = readlinesync.question(`> Please provide the account for refunding: `);
            let transactionAmount = currentBalance - feeAmount;
            console.log(`+ Refunding excess Balance of ${transactionAmount} ECS to ${refundAccount}.`);

            const tx = {
                to: refundAccount,
                from: tempWallet.address,
                value: transactionAmount,
                gasPrice: feeData.gasPrice,
                gasLimit: '21000'
            };
            const signer = new ethers.Wallet(tempWallet.privateKey, provider);
            signer.sendTransaction(tx).then((txResponse) => {
                console.log(`Transaction hash: ${txResponse.hash}`)
            })
            .catch(error => {
                console.log('+', 'Refund failed.');
            });
        }
    }
}

async function generateTempWallet() {
    console.log("----------------------------------------- Generating temporary wallet for staking transactions --------------------------------------------------------------------");
    console.log();
    console.log("We'll create a temporary account from where we'll send the staking deposit to the contract. Once that account is set up, please transfer the required amount of ECS ");
    console.log("to it for staking.");
    console.log("We'll create a keystore file for this account within the ouptut directory so you can access your funds in case the process get's interrupted.");
    let temp_keystore_password = readlinesync.question('Please provide the password to encrypt the keystore for the temporary wallet: ', { hideEchoBack: true });
    let tempWallet = await createWallet(temp_keystore_password)
        .catch(error => {
            console.log('+', 'Create wallet failed.');
        });
    console.log(tempWallet.address);
    console.log("+ Temporary wallet creation finished.");
    console.log();
    return tempWallet;
}

async function main(stakingonly) {
    var temp_account_mnemonic = create_mnemonic();
    let key_generation_done = false;
    console.log();
    console.log("        |");
    console.log("       / \\");
    console.log("      / _ \\");
    console.log("     |.o '.|");
    console.log("     |'._.'|                            eCredits - Key generation and deposit utility");
    console.log("     |     |");
    console.log("   ,'|  |  |\`.");
    console.log("  /  |  |  |  \\");
    console.log("  |,-'--|--'-.|");
    console.log("--------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    console.log();

    if (!stakingonly) {
        let execution_address = readlinesync.question('Please enter the address where your staking deposit should be refundend to: ');
        console.log();
        tempWallet = await generateTempWallet()
            .catch(error => {
                console.log('+', 'Create temp wallet failed.');
            });
        console.log("--------------------------------------------------------- Generating keys -----------------------------------------------------------------------------------------");
        console.log();
        console.log("In the next step we'll generate the validator keys that will be required to register and run you nodes.): ");
        let number_of_validators = readlinesync.question("+ Please enter the number of validators you plan to run (you have to stake 256 ECS for each validator!): ");
        console.log();
        key_mnemonic = create_mnemonic();
        console.log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        console.log("!!! Please store the following seed phrase in a secure location as you'll need it to recover your accounts! It is used to create the keys for your validators!  !!!");
        console.log("--------------------------------------------------------------------------------------------------------------------------------------------------------------------");
        console.log(key_mnemonic);
        console.log("--------------------------------------------------------------------------------------------------------------------------------------------------------------------");

        
        //TODO: Optimize python process integration
        const pythonProcess = spawn('python3', ["/app/staking_deposit/deposit.py",
            "--language",
            "English",
            "--non_interactive",
            "existing-mnemonic",
            "--chain",
            `${stakingCliEcsFlag}`,
            "--folder",
            `${OUTPUT_DIR}`,
            "--validator_start_index",
            "0",
            "--num_validators",
            `${number_of_validators}`,
            "--execution_address",
            `${execution_address}`,
            "--mnemonic",
            `${key_mnemonic}`
        ],
            { cwd: "/app" });

        pythonProcess.stdout.on('data', (data) => {
            if (data.includes("Create a password")) {
                console.log(`${data}`);
            }
        });
        pythonProcess.stderr.on("data", (data) => {
            console.log(`stderr: ${data}`);
        });
        pythonProcess.on('exit', code => {
            console.log(`+ Key generation completed.`);
            let depositDataPath = getDepositDataPath();

            depositStake(tempWallet, depositDataPath[depositDataPath.length - 1], number_of_validators)
                .then(() => {
                    refundRemainingBalance(tempWallet);
                });
        });
    }
    else {
        console.log(`-------------------------------------------------------- Staking only process -------------------------------------------------------------------------------------`);

        depositDataLogFile = `${OUTPUT_DIR}/deposit_log.json`
        backupFileName = `${OUTPUT_DIR}/deposit_log_${timestamp}.json`
        let depositDataLog = {};
        try {
            depositDataLog = JSON.parse(fs.readFileSync(depositDataLogFile));
            fs.copyFileSync(depositDataLogFile,backupFileName,fs.constants.COPYFILE_EXCL);
            console.log(`+ Using file at ${depositDataLogFile} to dertermine previous progress.`);
        }
        catch (error) {
            depositDataLog = {};
            console.log(`+ No deposit_log.json found. Reprocessing all keys.`);
        }

        let depositDataPath = getDepositDataPath();
        console.log(`+ Processing keys from Deposit Data file ${depositDataPath}.`);
        tempWallet = await generateTempWallet()
            .catch(error => {
                console.log('+', 'Create temp wallet failed.');
            });
        let number_of_validators = readlinesync.question("+ Please enter the number of validators you plan to re-run (you have to stake 256 ECS for each validator!): ");
        console.log();
        depositStake(tempWallet, depositDataPath[depositDataPath.length - 1], number_of_validators, depositDataLog)
            .then(() => {
                refundRemainingBalance(tempWallet);
            });
    }
}


if (process.argv.length == 4 || process.argv.length == 3) {
    network = process.argv[2]
    if (network == "mainnet") {
        console.log("Runing key generation and staking for MAINNET!");
        rpcUrl = 'https://rpc.ecredits.com';
        depositContractAddress = "0x1C98eDf5027f4a6713f66BC643a1BA62f769843D";
        stakingCliEcsFlag = "ecs"
    }
    else if (network == "testnet") {
        console.log("Runing key generation and staking for TESTNET!");
        rpcUrl = 'https://rpc.tst.esync.network';
        depositContractAddress = "0xE6CffD333C5e1775C04CAa2Fb3eD69A5AC29f3a5";
        stakingCliEcsFlag = "ecs-testnet";
    }
    else {
        console.log("Unknown network configuration.")
        exit;
    }

    if(process.argv.length == 4){
        if (process.argv[3] == "stakingonly") {
            stakingonly = true;
            main(stakingonly);
        }
        else {
            console.log("- Unknown command line argument. Stopping process.");
            exit;
        }
    }
    else {
        stakingonly = false;
        main(stakingonly);
    }
}
else {
    console.log("- Unknown number of command line arguments. Only 2 are allowed!");
    console.log("- Argument 1: Network to be used. Can be mainnet or testnet");
    console.log("- Argument 2: Optional specify if you want to only run the staking process. Value: stakingonly");
}



