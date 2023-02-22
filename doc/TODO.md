# next todos

1. monitordocker.sh
2. bootstrap.sh deploy/rm stacks (+ rescale?)
3. test-network/CHAINCODE_AS_A_SERVICE_TUTORIAL.md
4. join peers, deploy chaincode
   1. foodchain
      1. channel configuration transactions and anchor peer update transactions
      2. create channels
      3. install and instantiate chaincodes
      4. check channels/cahicode
   2. test-net
      1. createChannel() -> scripts/createChannel.sh
      2. deployCC() -> scripts/deployCC.sh
      3. deployCCAAS() ???
5. data/storage mounts from nfs
   [1.](https://stackoverflow.com/questions/64429252/make-docker-swarm-use-same-volumes-from-docker-compose/64430006?noredirect=1#comment113933104_64430006)
   [2.](https://stackoverflow.com/questions/45282608/how-to-directly-mount-nfs-share-volume-in-container-using-docker-compose-v3)
   [3.](https://hub.docker.com/r/erichough/nfs-server)
   [4.](https://hub.docker.com/r/itsthenetwork/nfs-server-alpine)
   [5.](https://blog.ruanbekker.com/blog/2020/09/20/setup-a-nfs-server-with-docker/)
6. swarm worker setup (over ssh, w/ nfs)
7. dedicated mgmt/metrics network?
8. grafana and portainer passwords in docker secrets?
9. syslog (w/ logspout)?
