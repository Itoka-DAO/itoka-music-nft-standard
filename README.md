# Itoka music NFT Standard

We propose a new NFT standard based on Internet Computer Protocol(ICP) to serve the audio streaming and music copyright protection. The architecture is implemented on the top of ERC721. The attached unique API features include the streaming control/record, download control/record and revenue collection. We are open for suggestions and community collaboration.

## Roadmap(Draft)

- Build ERC721-like NFT on IC canister with off-chain metadata
  - Deploy the pure ERC721 on IC by Motoko✔️
  - Add metadata and CDN from AWS ✔️
  - Add Internet Identity auth ✔️
  - Add frontend for mint/transfer and ledger ✔️
  - Deploy NFT on IC main-net ✔️
  - Add the NFT token in 3rd party wallet
- Upgrade from off-chain to on-chain
- Implement streaming control/record API
- Implement revenue collection ledger and API
- Implement download control/record API

## How to use?

### Prerequisites

1. `dfx` ^0.8.3
2. `Internet Identity`

## Setup

First clone `Itoka` and `Internet Identity` repo on under the same directory

```shell
git clone git@github.com:YihaoChen96/Itoka.git
git clone https://github.com/dfinity/internet-identity.git
```

Install dependency for `Internet Identity`. See https://github.com/dfinity/internet-identity how to installed on your local computer

Install npm dependency under `Itoka` and run the script to launch the app

```shell
cd Itoka
npm install
sudo ./launch.sh
```

Watch the console and you would find where to access the frontend. In defaut it should be `localhost:8080`. For example:

```shell
No production canister_ids.json found. Continuing with local
<i> [webpack-dev-server] [HPM] Proxy created: /api  -> http://localhost:8000
<i> [webpack-dev-server] [HPM] Proxy rewrite rule created: "^/api" ~> "/api"
<i> [webpack-dev-server] Project is running at:
<i> [webpack-dev-server] Loopback: http://localhost:8080/
```

Note: the `Itoka` and `internet-identity` must be under the same directory to run the script `./launch.sh`. The script will help you to deploy the local internet identity canister and configure the proxy, or you have to manually build and deploy each canister.
![image](https://user-images.githubusercontent.com/46518089/154343451-85876600-9c66-4b09-aa1f-3e53bed8f8f4.png)

## Metadata specifications

There are 3 audio assets for each single NFT song: 1. `.wav` raw soundtrack 2. `.map3` compressed soundtrack 3. `.mp3` compressed soundtrack for first 30 seconds preview. All assets are encrypted via `aes256`![link](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) algorithm. There is the sample code to demonstrate how to encrypt and decrypt asset by nodeJS:

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

# Reference

### NFT stardard

Appreciate the inspiration from Gigaverse lab(ICpunk & Market place): https://github.com/stopak/ICPunks/tree/master.

ERC721-like Motoko implementation on IC from Rocklabs: https://github.com/rocklabs-io/ic-nft

DIP721 Rust implementation from Psychedelic(Plug & DAB): https://github.com/Psychedelic/DIP721/blob/develop/src/main.rs

EXT Motoko implementation from Toniq-Labs(Stoic & Entrepot market place): https://github.com/Toniq-Labs/extendable-token/blob/main/examples/erc721.mo

### NFT IC registry

DAB Registry Standard: https://docs.dab.ooo/

### Frontend

Internet Identity authentication by frontend: https://github.com/krpeacock/auth-client-demo.git
