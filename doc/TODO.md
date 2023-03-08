# todo

1. setGlobals.sh
   1. genesis: gen env files
2. create channel sh (1. generic SC_createChannel func 2. wrap it around with sh)
   1. _GenesisBlock & _CreateChannel -> SC_CreateChannel()
   2. shell script wrapper for SC_CreateChannel()
   3. from swarm host and from cli container
3. join peer sh
4. fetch config sh
5. anchor.sh
6. join peers, deploy chaincode
   1. foodchain
      1. channel configuration transactions and anchor peer update transactions
      2. create channels
      3. install and instantiate chaincodes
      4. check/list channels/chaincode
   2. test-net
      1. createChannel() -> scripts/createChannel.sh
      2. deployCC() -> scripts/deployCC.sh
      3. [deployCCAAS()](https://github.com/hyperledger/fabric-samples/blob/main/test-network/CHAINCODE_AS_A_SERVICE_TUTORIAL.md)
7. data/storage mounts from nfs
   [1.](https://stackoverflow.com/questions/64429252/make-docker-swarm-use-same-volumes-from-docker-compose/64430006?noredirect=1#comment113933104_64430006)
   [2.](https://stackoverflow.com/questions/45282608/how-to-directly-mount-nfs-share-volume-in-container-using-docker-compose-v3)
   [3.](https://hub.docker.com/r/erichough/nfs-server)
   [4.](https://hub.docker.com/r/itsthenetwork/nfs-server-alpine)
   [5.](https://blog.ruanbekker.com/blog/2020/09/20/setup-a-nfs-server-with-docker/)
8. swarm worker setup (over ssh, w/ nfs)
9. split framework functions/variables (move them to dedicated repo, will be used as a submodule), SC_* functions/variables in common.sh
10. make sc*.sh (bootstrap, genesis...) scripts source-able and generic: dummy mode, rename functions, eliminate SC_* variables
11. CA
12. syslog (w/ logspout)?
13. dedicated mgmt/metrics network?
14. grafana and portainer passwords in docker secrets?
15. zsh/sh port?
