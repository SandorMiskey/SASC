export SC_SG_ORG_NAME=${SC_ORG2_NAME}
export SC_SG_ORG_DOMAIN=${SC_ORG2_DOMAIN}
export SC_SG_PEER_NAME=${SC_ORG2_P1_NAME}
export SC_SG_PEER_FQDN=${SC_ORG2_P1_FQDN}
export SC_SG_PEER_PORT=${SC_ORG2_P1_PORT}

export ORDERER_CA=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/tlsca/tlsca.${SC_ORDERER1_DOMAIN}-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.key

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="${SC_ORG2_NAME}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${SC_INTERFACES_CLI_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/tlsca/tlsca.${SC_ORG2_DOMAIN}-cert.pem
export CORE_PEER_MSPCONFIGPATH=${SC_INTERFACES_CLI_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/users/Admin@${SC_ORG2_DOMAIN}/msp
export CORE_PEER_ADDRESS=${SC_ORG2_P1_FQDN}:${SC_ORG2_P1_PORT}
