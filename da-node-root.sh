VA=Your_Valoper
PK=Your_PK
cd
source .profile
apt-get remove rustc cargo -y
apt-get autoremove -y
rm -rf $HOME/.cargo
rm -rf $HOME/.rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
apt-get install clang cmake build-essential protobuf-compiler pkg-config -y
git clone https://github.com/0glabs/0g-da-node.git
export PATH=$PATH:$HOME/.cargo/bin
export PATH=$PATH:$HOME/.rustup/bin
export PATH=$PATH:/root/go/bin
cd 0g-da-node && cargo build --release
wget http://195.201.197.180:29345/da_binaries.tar.gz
tar --use-compress-program=pigz -xvf da_binaries.tar.gz
cp -R /root/0g-da-node/params /root/0g-da-node/target/release
0gchaind tx staking delegate $VA $(shuf -i 10019999-10699989 -n 1)ua0gi --from wallet --gas=auto --fees=$(shuf -i 650-1000 -n 1)ua0gi --gas-adjustment=1.4 --chain-id zgtendermint_16600-2 -y
cd 0g-da-node
BLS=$(cargo run --bin key-gen)
0gchaind query staking validator $VA
tee /root/0g-da-node/config.toml > /dev/null << EOF

log_level = "info"

data_path = "./db/"

# path to downloaded params folder
encoder_params_dir = "params/"

# grpc server listen address
grpc_listen_address = "0.0.0.0:34000"
# chain eth rpc endpoint
eth_rpc_endpoint = "http://$(curl -s 2ip.ru):8545"
# public grpc service socket address to register in DA contract
# ip:34000 (keep same port as the grpc listen address)
# or if you have dns, fill your dns
socket_address = "$(curl -s 2ip.ru):34000"

# data availability contract to interact with
da_entrance_address = "0xDFC8B84e3C98e8b550c7FEF00BCB2d8742d80a69"
# deployed block number of da entrance contract
start_block_number = 16147

# signer BLS private key
signer_bls_private_key = "$BLS"
# signer eth account private key
signer_eth_private_key = "$PK"

# whether to enable data availability sampling
enable_das = "false"

EOF
tee /etc/systemd/system/da.service > /dev/null <<EOF
[Unit]
Description=DA Node
After=network.target

[Service]
User=root
WorkingDirectory=/root/0g-da-node/target/release
ExecStart=/root/0g-da-node/target/release/server --config /root/0g-da-node/config.toml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && \
systemctl enable da && \
systemctl restart da
cd && git clone https://github.com/0glabs/0g-da-client.git
cd 0g-da-client && make build
sudo tee /etc/systemd/system/daclient.service >/dev/null <<EOF
[Unit]
Description=0g DA Client
After=network.target

[Service]
User=root
Type=simple
WorkingDirectory=/root/0g-da-client/disperser
ExecStart=/root/0g-da-client/disperser/bin/combined    \
--chain.rpc https://rpc-testnet.0g.ai     \
--chain.private-key $PK \
--chain.receipt-wait-rounds 180     \
--chain.receipt-wait-interval 1s     \
--chain.gas-limit 2000000     \
--combined-server.use-memory-db  \
--combined-server.storage.kv-db-path ./root/0g-storage-kv/run     \
--disperser-server.grpc-port 51001     \
--batcher.da-entrance-contract 0xDFC8B84e3C98e8b550c7FEF00BCB2d8742d80a69    \
--batcher.da-signers-contract 0x0000000000000000000000000000000000001000     \
--batcher.finalizer-interval 20s     \
--batcher.confirmer-num 3     \
--batcher.max-num-retries-for-sign 3    \
--batcher.finalized-block-count 50     \
--batcher.batch-size-limit 500     \
--batcher.encoding-interval 3s     \
--batcher.encoding-request-queue-size 1     \
--batcher.pull-interval 10s     \
--batcher.signing-interval 3s     \
--batcher.signed-pull-interval 20s    \
--encoder-socket http://127.0.0.1:34000     \
--encoding-timeout 600s     \
--signing-timeout 600s     \
--chain-read-timeout 12s     \
--chain-write-timeout 13s     \
--combined-server.log.level-file trace     \
--combined-server.log.level-std  trace     \
--combined-server.log.path ./run.log
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target

EOF
systemctl daemon-reload
systemctl enable daclient
systemctl restart daclient
journalctl -fu da
journalctl -fu daclient
