# Introduction 
This repo holds te script files to manage and setup an ecredits node.

# ./script/nuc
The folder nuc holds all scripts that are required to setup an eCredits node. A detailed description on how the setup needs to be done can be found in the [eCredits Production Wiki](https://dev.azure.com/cryptixch/eCredits%20Production/_wiki/wikis/Wiki/140/seed_image_preparation)

Also these scripts are used by the community now.

# ./eth2_scripts
This folder holds the modifications to the staking_deposit_cli that where done to improve the key generation and staking experience for the eCredits users.
If staking for a validator is needed the following process can be followed:
1. Copy the respective keys, including the deposit-data.json into the gened/validator_keys folder
2. Copy a possible existing deposit_log.json file into the gened folder
3. Use one of the following scripts to run the staking process:
   1. run_setup_mainnet.ps1 - This will generate keys and stake for the mainnet
   2. run_setup_staking_mainnet.ps1 - This will only stake for the keys that are located in gened/validator_keys for the mainnet
   3. run_setup_testnet.ps1 - This will generate and stake keys for the testnet
   4. run_setup_staking_testnet.ps1 - This will only stake for the keys that are located in gened/validator_keys for the testnet

Step 1 and 2 only need to be done if you wnat to stake for existing key's. Otherwhise you can skip those.

## Build the dockerfile
If you need to release a new version, simply build the dockerfile and push it to dockerhub (https://hub.docker.com/r/ecredits/staking-deposit-cli).
The version number is increased as follows:
version = <staking_deposti_cli_version>-ecs-<increased number for ecs specific changes>

You can use the following commands step by step:
1. docker build -t pallas.azurecr.io/ecredits/staking-deposit-cli:<version> .

# ./DNS discovery
This folder holds a check script that can be used to verify how many of our nodes are covered by a DNS discovery update.