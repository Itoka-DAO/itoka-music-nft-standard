   /**
 * Module     : types.mo
 * Copyright  : 2021 Rocklabs Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Rocklabs Team <hello@rocklabs.io>
 * Stability  : Experimental
 */

import Time "mo:base/Time";
import TrieSet "mo:base/TrieSet";

module {
    public type Metadata = {
        logo: Text;
        name: Text;
        symbol: Text;
        desc: Text;
        totalSupply: Nat;
        owner: Principal;
        cycles: Nat;
        custodians: [Principal];
        created_at : Time.Time;
        upgraded_at : Time.Time;
    };

    public type AudioLocation = {
        icp: Text;// ICP canister URL 
        ipfs: Text; // IPFS URL
    };

    public type AlbumCoverLocation = {
        icp: Text; // ICP canister URL
        ipfs: Text; // IPFS URL
    };

    public type Attribute = {
        name: Text;
        genre: [Text];
        bpm: Nat;
        collection: Text;
        key: Text;
        backbone: Text;
    };

    public type TokenMetadata = {
        tokenIdentifier: Text; // audio hex raw data encoded by SHA-256 

        rawAudioType: Text; // .wav raw
        rawAudioLocation: AudioLocation; // IPFS+InCanister,CDN URL

        compressedAudioType: Text; // .mp3 full low quality
        compressedAudioLocation: AudioLocation; // IPFS+InCanister,CDN URL

        previewAudioType: Text; // .mp3 first 30s
        previewAudioLocation: AudioLocation; // IPFS+InCanister,CDN URL

        albumCoverType: Text; // .png
        albumCoverLocation: AlbumCoverLocation;// IPFS+InCanister,CDN URL

        attributes:Attribute;
    };
    // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    public type DecryptionKey ={
        iv:Text;
        privateKey:Text;
    };

    public type TokenInfo = {
        index: Nat;
        var owner: Principal;
        var metadata: ?TokenMetadata;
        var operator: ?Principal;
        timestamp: Time.Time;
    };

    public type TokenInfoExt = {
        index: Nat;
        owner: Principal;
        metadata: ?TokenMetadata;
        operator: ?Principal;
        timestamp: Time.Time;
    };
    public type UserInfo = {
        var operators: TrieSet.Set<Principal>;     // principals allowed to operate on the user's behalf
        var allowedBy: TrieSet.Set<Principal>;     // principals approved user to operate their's tokens
        var allowedTokens: TrieSet.Set<Nat>;       // tokens the user can operate
        var tokens: TrieSet.Set<Nat>;              // user's tokens
    };

    public type UserInfoExt = {
        operators: [Principal];
        allowedBy: [Principal];
        allowedTokens: [Nat];
        tokens: [Nat];
    };
    /// Update call operations
    public type Operation = {
        #mint: ?TokenMetadata;  
        #burn;
        #transfer;
        #transferFrom;
        #approve;
        #approveAll;
        #revokeAll; // revoke approvals
        #setMetadata;
        #setTranscationFee;
        #setStreamingRoyalty;
        

        #setAudioPreviewSrc;
        #retriveAudioPreviewSrc;

        #setAudioCompressedSrc;
        #retriveAudioCompressedSrc;
        
        #setAudioRawSrc;
        #retriveAudioRawSrc;

        #setDecryptionKey;
        #retriveDecryptionKey;


        #upgrade;
    };
    /// Update call operation record fields
    public type Record = {
        #user: Principal;
        #metadata: ?TokenMetadata; // op == #setMetadata
        #transcationFee: Nat;
        #secret :Text;
        #commit: UpgradeHistory;
    };
    
    public type UpgradeHistory = {
        message: Text;
        upgrade_time: Time.Time;
    };

    public type TxRecord = {
        caller: Principal;
        op: Operation;
        index: Nat;
        tokenIndex: ?Nat;
        from: Record;
        to: Record;
        timestamp: Time.Time;
    };
};
