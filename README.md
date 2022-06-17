# Itoka music NFT Standard

We propose a new NFT standard for Internet Computer Protocol(ICP) to serve on-chain audio streaming and music copyright protection. The architecture is implemented on the top of Rocklabs' [`ic-nft`](https://github.com/rocklabs-io/ic-nft), an ERC721-like NFT implementation. The extended API functions include the retrieval of encrypted assets, streaming control and royalty collection, etc. The goal of this project is to leverage the NFT power to build a transparent, trustless, and permanent streaming protocol for the digital music assets. 

Itoka’s genesis airdrop (72 music NFTs) has been completed on 05/20/2022, as we promised to our community. 

The following are the id and links to our canisters:

:point_right: Itoka NFT canister ID: 4y4bz-6aaaa-aaaai-acj4a-cai

:point_right: Candid UI: https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.ic0.app/?id=4y4bz-6aaaa-aaaai-acj4a-cai

:point_right: Itoka µxive frontend: https://ku323-qyaaa-aaaai-ackgq-cai.ic0.app/airdrop

The project is under development. We are open for suggestions and community collaboration. Join [Itoka official discord](https://discord.gg/7BqSGMCE5c) for further discussion.

## NFT developement Roadmap(Draft)

- Integrate ERC721-like NFT on IC canister with off-chain metadata
  - Deploy the pure ERC721 on IC by Motoko✔️
  - Add metadata and CDN from AWS ✔️
  - Add Internet Identity auth ✔️
  - Add frontend for mint/transfer and ledger ✔️
  - Deploy NFT on IC main-net ✔️
  - Add the NFT token to 3rd party wallets
- Upgrade from off-chain to on-chain 
  - Design metadata format ✔️
  - Design encryption mechanism ✔️
- Implement streaming control API
  - Implement the streaming ledger ✔️
  - Implement the listener authentication for streaming ✔️
  - Implement the listener-controlled streaming authorization (Digital Rights Management)
- Implement royalty collection ledger and API
  - Design the music royalty collection protocol
  - Enable the trustless royalty collection for Itoka NFT 
    - Accept royalty by $ITOKA and $ICP
    - *Accept royalty by BTC, ETH etc. once Dfinity completed BTC/ETH intergration 
- Initiate cross-chain trading and streaming for Itoka

## How to use?

### Prerequisites

1. `dfx` ^0.10.0 

### Setup

First clone `itoka-music-nft-standard` repo

```shell
git clone https://github.com/ItokaDAO/itoka-music-nft-standard.git
```

[Optional] We highly recommend to clone `Internet Identity` repo under the same directory for later testing

```shell
git clone https://github.com/dfinity/internet-identity.git
```

Run bash script to install dependency 

```shell
cd Itoka
npm install
sudo ./install.sh
```
Note that the `install.sh` includes the dependency of `internet identity` local deployment. Please walk through `install.sh` if you want to manually configure the   dependency. 

### Locally deploy smart contract and mint NFT

Run run Python script to locally deploy canister and mint example NFTs

```shell
python mint_nft.py
```
Now you could check the API on default local Candid UI:  http://localhost:8000/?canisterId=ryjl3-tyaaa-aaaaa-aaaba-cai&id=rrkah-fqaaa-aaaaa-aaaaq-cai

## Assets encryption

Each NFT aligned 3 audio data: (1) the first 30 seconds preview(.mp3), (2) full song compressed audio (.mp3) and (3) raw sound (.wav). The preview and compressed audio intend to support streaming, and raw sound is for collection and archiving. The audio source is a static URL and retrieved by NFT API if the caller is authorized. Meanwhile, we also encrypt all audio data to JSON by [`aes256`](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) algorithm and dump it in tokens metadata for proof of content existence and future development. Only the owner of the NFT is eligible to retrieve the decryption key to decode the JSON file.

There is the sample code to demonstrate how to encrypt and decrypt assets by nodeJS:

```javascript
function generate_key() {
  // Defining key
  const key = crypto.randomBytes(32).toString("hex");

  // Defining iv
  const iv = crypto.randomBytes(16).toString("hex");
  return { iv, key };
}

function encrypt(algorithm, text, key, iv) {
  const cipher = crypto.createCipheriv(
    algorithm,
    Buffer.from(key, "hex"),
    Buffer.from(iv, "hex")
  );

  const encrypted = Buffer.concat([cipher.update(text), cipher.final()]);

  return {
    iv: iv.toString("hex"),
    content: encrypted.toString("hex"),
  };
}

function decrypt(algorithm, hash, secretKey) {
  const decipher = crypto.createDecipheriv(
    algorithm,
    Buffer.from(secretKey, "hex"),
    Buffer.from(hash.iv, "hex")
  );

  const decrpyted = Buffer.concat([
    decipher.update(Buffer.from(hash.content, "hex")),
    decipher.final(),
  ]);

  return decrpyted.toString();
}

// generate private key and iv
let temp = generate_key();
let prviateKey = temp.key;
let iv = temp.iv;

// read .wav
let buff = fs.readFileSync(wav_dir);
text = buff.toString("base64");

// Encryption
let hash_wav = encrypt("aes256", text, prviateKey, iv);
let text_back = decrypt("aes256", hash_wav, prviateKey);
console.log(text == text_back); // expected return True
```

## How to get each NFT information and metadata?

`getTokenInfo:(nat)` and `getAllTokens: ()` are public query APIs and return basic NFT metadata including encrypted audio data, owner, minting timestamp, etc.
 
`getTokenAudioTotalStreamingAmount: (nat) ` returns the underlying token total streaming counts including preview, compressed and raw. 

Similarly, `getTokenAudioPreviewStreamingAmount: (nat)`, `getTokenAudioCompressedStreamingAmount: (nat)`, `getTokenAudioRawStreamingAmount: (nat)` return the sub-category streaming amounts

The getter functions are fast public queries and **will not make records**.

`retriveAudioPreviewSrc: (nat, principal)`,`retriveAudioCompressedSrc: (nat, principal)`,`retriveRawAudioSrc: (nat, principal)` returns the source of the relevant audible assets by argumenting the NFT index and listener identity.

The retriever functions authenticate the caller and **will make records on ledger**, which is the proof for royalty collection. 

## Open discussion and research

1. Since we web3 is still at its early stage, the streaming performance of `ICP` and `IPFS` is not fully unleashed, especially in some regions with no operating nodes. Therefore, we make identical audio source copies on both chains available for downstream application depending on the use cases. Based on our community members' feedback, the `ICP` can provide fast streaming in most countries but might fail if the data is too large. Developers will need to implement the backend to decompose the data to chunk and reassemble on the client side. See details [here](https://forum.dfinity.org/t/service-worker-bug-body-does-not-pass-verification/7673). The `IPFS` is a convenient and cheap data storage solution but might not be available in some other regions like China and Japan. Currently, we stream preview audio from `ICP` and compressed full music from `IPFS` on [Itoka µxive](https://ku323-qyaaa-aaaai-ackgq-cai.ic0.app/airdrop) and might be adjusted in the future.     

2. We are unable to upload all data within one assets canister since the single ICP canister can only support 4G maximum on chain data so far. Thus, We upload the JSON to IPFS and are waiting for Dfinity upgrade. 

3. Currently the decryption key is static and might be upgraded to a dynamic one to improve the security. We would like to discuss necessary improvements after Dfinity enables canister HTTP outbound requests. 

4.  What about music royalty collection protocol? The most interesting practice is passing this power to a decentralized autonomous organization(DAO) to vote and automatically adopt this numerical in the NFT smart contract. Dfinity provide a wonderful DAO infrastructure [SNS](https://medium.com/dfinity/how-the-service-nervous-system-sns-will-bring-tokenized-governance-to-on-chain-dapps-b74fb8364a5c) as a starting point. Before the DAO is offically established, the Itoka team and OctAI Inc. reserve the right to determine its implementation.

# Reference

### IC NFT stardard

ERC721-like Motoko implementation on IC from Rocklabs: https://github.com/rocklabs-io/ic-nft

DIP721 Rust implementation from Psychedelic(Plug & DAB): https://github.com/Psychedelic/DIP721/blob/develop/src/main.rs

EXT Motoko implementation from Toniq-Labs(Stoic & Entrepot market place): https://github.com/Toniq-Labs/extendable-token/blob/main/examples/erc721.mo

3C NFT standard from C3-Protocol(CCCMarketplace): https://github.com/C3-Protocol/NFT-standards

Appreciate the inspiration from Gigaverse lab(ICpunk & Market place): https://github.com/stopak/ICPunks/tree/master.

### IC NFT registry

DAB : https://docs.dab.ooo/

### Frontend

Internet Identity authentication by frontend: https://github.com/krpeacock/auth-client-demo.git

# Sponsorship

This project is sponsored by by [Dfinity Developer Grant](https://dfinity.org/grants/) in 2021-2022 
