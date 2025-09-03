FROM pallas.azurecr.io/ecredits/staking-deposit-cli:latest

RUN apk add nodejs-current npm --no-cache

RUN mkdir /setup

WORKDIR /setup

RUN npm install ethers readline-sync python-shell

COPY eth2_setup_node.js deposit_contract.json /setup/

ARG cli_command

ENTRYPOINT [ "/bin/ash" ]

CMD [ ${cli_command} ]