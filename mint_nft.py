import os
import json

# \
slach = chr(92)
# "
quote = chr(34)
# '
quote_one = chr(39)
# \"
slach_quote = chr(92)+chr(34)


os.system("killall dfx;")
os.system("rm -rf .dfx;")
os.system("dfx start --clean --background;")
os.system("dfx canister create itoka_nft;")
os.system("dfx build")
install = "dfx canister install itoka_nft --argument={}($(cat ./metadata/collection/logo.json | jq {}.text{}), {}Itoka{}, {}ITOKA{}, {}Fisrt music NFT project in ICP{}, principal {}$(dfx identity get-principal){}, null){};".format(quote,quote_one,quote_one,slach_quote,slach_quote,slach_quote,slach_quote,slach_quote,slach_quote,slach_quote,slach_quote,quote)
print(install)
os.system(install)

f = open('./metadata/token/metadata.json')
data = json.load(f)
MINT_NUMBER = 2

for i in range(0,MINT_NUMBER):
    admin_principal="principal {}$(dfx identity get-principal){}".format(slach_quote,slach_quote)
    token_0 = data["metadata"][str(int(i))]
    iv = token_0['iv']
    privateKey = token_0['privateKey']

    mp3PreviewAudioSrc = token_0['mp3PreviewAudioSrc']
    mp3FullAudioSrc = token_0['mp3FullAudioSrc']
    wavAudioSrc = token_0['wavAudioSrc']

    tokenIdentifier = token_0['tokenIdentifier']
    rawAudioType = token_0['rawAudioType']
    rawAudioLocation = token_0['rawAudioLocation']
    rawAudioLocation_icp = rawAudioLocation['icp']
    rawAudioLocation_ipfs = rawAudioLocation['ipfs']

    compressedAudioType = token_0["compressedAudioType"]
    compressedAudioLocation = token_0['compressedAudioLocation']
    compressedAudioLocation_icp = compressedAudioLocation['icp']
    compressedAudioLocation_ipfs = compressedAudioLocation['ipfs']

    previewAudioType = token_0["previewAudioType"]
    previewAudioLocation = token_0['previewAudioLocation']
    previewAudioLocation_icp = previewAudioLocation['icp']
    previewAudioLocation_ipfs = previewAudioLocation['ipfs']

    albumCoverType = token_0['albumCoverType']
    albumCoverLocation = token_0['albumCoverLocation']
    albumCoverLocation_icp = albumCoverLocation['icp']
    albumCoverLocation_ipfs = albumCoverLocation['ipfs']

    attributes = token_0['attributes']
    attributes_name = attributes['name']
    attributes_genre = attributes['genre']
    attributes_bpm = attributes['bpm']
    attributes_collection = attributes['collection']
    attributes_key = attributes['key']
    attributes_backbone = attributes['backbone']


    tokenIdentifier = "tokenIdentifier = {}{}{}".format(slach_quote,tokenIdentifier,slach_quote)

    rawAudioType = "rawAudioType = {}{}{}".format(slach_quote,rawAudioType,slach_quote)
    rawAudioLocation_icp ="icp = " +"{}{}{}".format(slach_quote,rawAudioLocation_icp,slach_quote)
    rawAudioLocation_ipfs ="ipfs = " + "{}{}{}".format(slach_quote,rawAudioLocation_ipfs,slach_quote)
    rawAudioLocation = "rawAudioLocation = record { "+"{};{};".format(rawAudioLocation_icp,rawAudioLocation_ipfs)+"}"
    compressedAudioType = "compressedAudioType = {}{}{}".format(slach_quote,compressedAudioType,slach_quote)
    compressedAudioLocation_icp ="icp = " +"{}{}{}".format(slach_quote,compressedAudioLocation_icp,slach_quote)
    compressedAudioLocation_ipfs ="ipfs = " + "{}{}{}".format(slach_quote,compressedAudioLocation_ipfs,slach_quote)
    compressedAudioLocation = "compressedAudioLocation = record { "+"{};{};".format(compressedAudioLocation_icp,compressedAudioLocation_ipfs)+"}"

    previewAudioType = "previewAudioType = {}{}{}".format(slach_quote,previewAudioType,slach_quote)
    previewAudioLocation_icp ="icp = " +"{}{}{}".format(slach_quote,previewAudioLocation_icp,slach_quote)
    previewAudioLocation_ipfs ="ipfs = " + "{}{}{}".format(slach_quote,previewAudioLocation_ipfs,slach_quote)
    previewAudioLocation = "previewAudioLocation = record { "+"{};{};".format(previewAudioLocation_icp,previewAudioLocation_ipfs)+"}"

    albumCoverType = "albumCoverType = {}{}{}".format(slach_quote,albumCoverType,slach_quote)
    albumCoverLocation_icp ="icp = " +"{}{}{}".format(slach_quote,albumCoverLocation_icp,slach_quote)
    albumCoverLocation_ipfs ="ipfs = " + "{}{}{}".format(slach_quote,albumCoverLocation_ipfs,slach_quote)
    albumCoverLocation = "albumCoverLocation = record { "+"{};{};".format(albumCoverLocation_icp,albumCoverLocation_ipfs)+"}"

    temp  = "vec {"
    for g in attributes_genre:
        temp  = temp+ "{}{}{};".format(slach_quote,g,slach_quote)
    temp = temp+" }"
    attributes_genre = temp
    attributes_name = "{}{}{}".format(slach_quote,attributes_name,slach_quote)
    attributes = "attributes = record{"+"name = {};".format(attributes_name)+"genre = {};".format(attributes_genre)+"bpm = {};".format(attributes_bpm)+"collection = {}{}{};".format(slach_quote,attributes_collection,slach_quote)+"key = {}{}{};".format(slach_quote,attributes_key,slach_quote)+"backbone = {}{}{};".format(slach_quote,attributes_backbone,slach_quote)+"}"

    TokenMetadata = "opt record {"+tokenIdentifier+";"+rawAudioType+";"+rawAudioLocation+";"+compressedAudioType+";"+compressedAudioLocation+";"+previewAudioType+";"+previewAudioLocation+";"+albumCoverType+";"+ albumCoverLocation+";"+attributes+";"+"}"
    mint = "dfx canister call itoka_nft mint {}({},{}){}".format(quote,admin_principal,TokenMetadata,quote)
    print("Mint the NFT...idx:{}".format(i))
    # print(mint)
    os.system(mint)

    # Add music src

    mp3PreviewAudioSrc = token_0['mp3PreviewAudioSrc']
    setPreviewAudioSource = "dfx canister call itoka_nft setAudioPreviewSrc {}({}:nat,{}{}{}){}".format(quote,i,slach_quote,mp3PreviewAudioSrc,slach_quote,quote)
    print("set Preview Audio Source...idx:{}".format(i))
    # print(setPreviewAudioSource)
    os.system(setPreviewAudioSource)


    mp3FullAudioSrc = token_0['mp3FullAudioSrc']
    setCompressedAudioSource = "dfx canister call itoka_nft setAudioCompressedSrc {}({}:nat,{}{}{}){}".format(quote,i,slach_quote,mp3FullAudioSrc,slach_quote,quote)
    # print(setCompressedAudioSource)
    print("set Compressed Audio Source...idx:{}".format(i))
    os.system(setCompressedAudioSource)


    wavAudioSrc = token_0['wavAudioSrc']
    setRawAudioSource = "dfx canister call itoka_nft setAudioRawSrc {}({}:nat,{}{}{}){}".format(quote,i,slach_quote,wavAudioSrc,slach_quote,quote)
    # print(setRawAudioSource)
    print("set Raw Audio Source...idx:{}".format(i))
    os.system(setRawAudioSource)
    # Add decryption key
    iv = token_0['iv']
    privateKey = token_0['privateKey']
    setDecryptionKey = "dfx canister call itoka_nft setDecryptionKey {}({}:nat,{}{}{},{}{}{}){}".format(quote,i,slach_quote,iv,slach_quote,slach_quote,privateKey,slach_quote,quote)
    print("set decryption key...idx:{}".format(i))
    # print(setDecryptionKey)
    os.system(setDecryptionKey)

