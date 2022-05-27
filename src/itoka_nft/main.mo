/**
 * Module     : main.mo
 * Copyright  : 2022 Itoka Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Itoka Team <octai@octaimusic.com>
 * Stability  : Experimental
 */


/**
    NOTICE
    Itoka NFT is building on the top of Rocklabs' ic-NFT. For NFT backbone please refer to https://github.com/rocklabs-io/ic-nft
    Major motification by Itoka: 
    *Add custodian management
    *Add upgrade history management
    *upgrade from Array to buffer
    *Add Streaming Protocol
 */



 

import HashMap "mo:base/HashMap";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import TrieSet "mo:base/TrieSet";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Types "./types";

shared(msg) actor class NFToken(
    _logo: Text,
    _name: Text, 
    _symbol: Text,
    _desc: Text,
    _owner: Principal,
    _transcationFee: ?Nat
    ) = this {

    // NFT attributes and functionalities
    type Metadata = Types.Metadata;
    type TokenMetadata = Types.TokenMetadata;
    type Record = Types.Record;
    type TxRecord = Types.TxRecord;
    type Operation = Types.Operation;
    type TokenInfo = Types.TokenInfo;
    type TokenInfoExt = Types.TokenInfoExt;
    type UserInfo = Types.UserInfo;
    type UserInfoExt = Types.UserInfoExt;

    public type Errors = {
        #Unauthorized;
        #TokenNotExist;
        #InvalidOperator;
    };
    // to be compatible with Rust canister
    // in Rust, Result is `Ok` and `Err`
    public type TxReceipt = {
        #Ok: Nat;
        #Err: Errors;
    };

    public type MintResult = {
        #Ok: (Nat, Nat);
        #Err: Errors;
    };


    private stable var logo_ : Text = _logo; // base64 encoded image
    private stable var name_ : Text = _name;
    private stable var symbol_ : Text = _symbol;
    private stable var desc_ : Text = _desc;
    private stable var owner_: Principal = _owner;
    
    //@Itoka: Add custodian 
    private stable var custodiansEntries : [Principal] = [];
    private var custodians = TrieSet.empty<Principal>();
    custodians := TrieSet.put(custodians,owner_,Principal.hash(owner_),Principal.equal);
    // [Warning] If you test on motoko playground you can add the anonymous identity as principal. but you should NEVER add anonymous identity in production  
    // custodians := TrieSet.put(custodians,Principal.fromText("2vxsx-fae"),Principal.hash(Principal.fromText("2vxsx-fae")),Principal.equal);
    private stable var totalSupply_: Nat = 0;
    private stable var blackhole: Principal = Principal.fromText("aaaaa-aa");
    private stable var tokensEntries : [(Nat, TokenInfo)] = [];
    private stable var usersEntries : [(Principal, UserInfo)] = [];
    private stable var txs: [TxRecord] = [];

    // Each TokenInfo contains idx, who is the owner, metadata, operator, and time
    private var tokens = HashMap.HashMap<Nat, TokenInfo>(1, Nat.equal, Hash.hash);    
    // Each UserInfo contains who can operate like owner, who approve the operators, which tokens can be operated
    private var users = HashMap.HashMap<Principal, UserInfo>(1, Principal.equal, Principal.hash);
    private stable var txIndex: Nat = 0;

    //@Itoka: replace all Array.append by Buffer
    private func Array_append<T>(xs:[T],ys:[T]):[T]{
        let zs : Buffer.Buffer<T> = Buffer.Buffer(xs.size()+ys.size());
        for (x in xs.vals()) {
            zs.add(x);
        };
        for (y in ys.vals()) {
            zs.add(y);
        };
        return zs.toArray();
    };

    private func addTxRecord(
        caller: Principal, op: Operation, tokenIndex: ?Nat,
        from: Record, to: Record, timestamp: Time.Time
    ): Nat {
        let record: TxRecord = {
            caller = caller;
            op = op;
            index = txIndex;
            tokenIndex = tokenIndex;
            from = from;
            to = to;
            timestamp = timestamp;
        };
        txs := Array_append(txs, [record]);
        txIndex += 1;
        return txIndex - 1;
    };

    private func _unwrap<T>(x : ?T) : T =
    switch x {
      case null { Prelude.unreachable() };
      case (?x_) { x_ };
    };
    
    private func _exists(tokenId: Nat) : Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return true; };
            case _ { return false; };
        }
    };

    private func _ownerOf(tokenId: Nat) : ?Principal {
        switch (tokens.get(tokenId)) {
            case (?info) { return ?info.owner; };
            case (_) { return null; };
        }
    };

    private func _isOwner(who: Principal, tokenId: Nat) : Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return info.owner == who; };
            case _ { return false; };
        };
    };

    private func _isApproved(who: Principal, tokenId: Nat) : Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return info.operator == ?who; };
            case _ { return false; };
        }
    };
    
    private func _balanceOf(who: Principal) : Nat {
        switch (users.get(who)) {
            case (?user) { return TrieSet.size(user.tokens); };
            case (_) { return 0; };
        }
    };

    private func _newUser() : UserInfo {
        {
            var operators = TrieSet.empty<Principal>();
            var allowedBy = TrieSet.empty<Principal>();
            var allowedTokens = TrieSet.empty<Nat>();
            var tokens = TrieSet.empty<Nat>();
        }
    };

    private func _tokenInfotoExt(info: TokenInfo) : TokenInfoExt {
        return {
            index = info.index;
            owner = info.owner;
            metadata = info.metadata;
            timestamp = info.timestamp;
            operator = info.operator;
        };
    };

    private func _userInfotoExt(info: UserInfo) : UserInfoExt {
        return {
            operators = TrieSet.toArray(info.operators);
            allowedBy = TrieSet.toArray(info.allowedBy);
            allowedTokens = TrieSet.toArray(info.allowedTokens);
            tokens = TrieSet.toArray(info.tokens);
        };
    };

    private func _isApprovedOrOwner(spender: Principal, tokenId: Nat) : Bool {
        switch (_ownerOf(tokenId)) {
            case (?owner) {
                return spender == owner or _isApproved(spender, tokenId) or _isApprovedForAll(owner, spender);
            };
            case _ {
                return false;
            };
        };        
    };

    private func _getApproved(tokenId: Nat) : ?Principal {
        switch (tokens.get(tokenId)) {
            case (?info) {
                return info.operator;
            };
            case (_) {
                return null;
            };
        }
    };

    //if operator can operate all of owner's NFT
    private func _isApprovedForAll(owner: Principal, operator: Principal) : Bool {
        switch (users.get(owner)) {
            case (?user) {
                return TrieSet.mem(user.operators, operator, Principal.hash(operator), Principal.equal);
            };
            case _ { return false; };
        };
    };

    // if the the owner is the new users, make a new empty UserInfo and add the current token to the user.tokens; 
    // Or directly add to existing users map
    private func _addTokenTo(to: Principal, tokenId: Nat) {
        switch(users.get(to)) {
            case (?user) {
                user.tokens := TrieSet.put(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(to, user);
            };
            case _ {
                let user = _newUser();
                user.tokens := TrieSet.put(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(to, user);
            };
        }
    }; 

    private func _removeTokenFrom(owner: Principal, tokenId: Nat) {
        assert(_exists(tokenId) and _isOwner(owner, tokenId));
        switch(users.get(owner)) {
            case (?user) {
                user.tokens := TrieSet.delete(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(owner, user);
            };
            case _ {
                assert(false);
            };
        }
    };
   
    private func _clearApproval(owner: Principal, tokenId: Nat) {
        assert(_exists(tokenId) and _isOwner(owner, tokenId));
        switch (tokens.get(tokenId)) {
            case (?info) {
                if (info.operator != null) {
                    let op = _unwrap(info.operator);// get the token's operator
                    let opInfo = _unwrap(users.get(op));// get operator's information
                    opInfo.allowedTokens := TrieSet.delete(opInfo.allowedTokens, tokenId, Hash.hash(tokenId), Nat.equal);
                    users.put(op, opInfo);
                    info.operator := null;
                    tokens.put(tokenId, info);
                }
            };
            case _ {
                assert(false);
            };
        }
    };  

    private func _transfer(to: Principal, tokenId: Nat) {
        assert(_exists(tokenId));
        switch(tokens.get(tokenId)) {
            case (?info) {
                _removeTokenFrom(info.owner, tokenId);
                _addTokenTo(to, tokenId);
                info.owner := to;
                tokens.put(tokenId, info);
            };
            case (_) {
                assert(false);
            };
        };
    };

    private func _burn(owner: Principal, tokenId: Nat) {
        _clearApproval(owner, tokenId);
        _transfer(blackhole, tokenId);
    };

    //@Itoka: add custodian can mint and adjust token metadata
    public shared(msg) func mint(to: Principal, metadata: ?TokenMetadata): async MintResult {
        // The only one who can mint NFT must be the owner or custodians
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        let token: TokenInfo = {
            index = totalSupply_;
            var owner = to;
            var metadata = metadata;
            var operator = null;
            timestamp = Time.now();
        };

        tokens.put(totalSupply_, token);
        _addTokenTo(to, totalSupply_);
        totalSupply_ += 1;
        let txid = addTxRecord(msg.caller, #mint(metadata), ?token.index, #user(blackhole), #user(to), Time.now());
        return #Ok((token.index, txid));
    };

    // public shared(msg) func batchMint(to: Principal, arr: [?TokenMetadata]): async MintResult {
    //     if(not _isCustodian(msg.caller)) {
    //         return #Err(#Unauthorized);
    //     };
    //     let startIndex = totalSupply_;
    //     for(metadata in Iter.fromArray(arr)) {
    //         let token: TokenInfo = {
    //             index = totalSupply_;
    //             var owner = to;
    //             var metadata = metadata;
    //             var operator = null;
    //             timestamp = Time.now();
    //         };
    //         tokens.put(totalSupply_, token);
    //         _addTokenTo(to, totalSupply_);
    //         totalSupply_ += 1;
    //         ignore addTxRecord(msg.caller, #mint(metadata), ?token.index, #user(blackhole), #user(to), Time.now());
    //     };
    //     return #Ok((startIndex, txs.size() - arr.size()));
    // };

    public shared(msg) func burn(tokenId: Nat): async TxReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        if(_isOwner(msg.caller, tokenId) == false) {
            return #Err(#Unauthorized);
        };
        _burn(msg.caller, tokenId); //not delete tokenId from tokens temporarily. (consider storage limited, it should be delete.)
        let txid = addTxRecord(msg.caller, #burn, ?tokenId, #user(msg.caller), #user(blackhole), Time.now());
        return #Ok(txid);
    };

    //@Itoka: add custodian can adjust token metadata
    public shared(msg) func setTokenMetadata(tokenId: Nat, new_metadata: TokenMetadata) : async TxReceipt {
        // only canister owner can set
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };
        let token = _unwrap(tokens.get(tokenId));
        let old_metadate = token.metadata;
        token.metadata := ?new_metadata;
        tokens.put(tokenId, token);
        let txid = addTxRecord(msg.caller, #setMetadata, ?token.index, #metadata(old_metadate), #metadata(?new_metadata), Time.now());
        return #Ok(txid);
    };

    public shared(msg) func approve(tokenId: Nat, operator: Principal) : async TxReceipt {
        // Check if the token exists
        var owner: Principal = switch (_ownerOf(tokenId)) {
            case (?own) {
                own;
            };
            case (_) {
                return #Err(#TokenNotExist)
            }
        };

        // Only owner and operator can use approve-[ERC721: approve caller is not owner nor approved for all]
        if(Principal.equal(msg.caller, owner) == false)
            if(_isApprovedForAll(owner, msg.caller) == false)
                return #Err(#Unauthorized);
        
        // the operator should not be owner-[ERC721: approval to current owner]
        if(owner == operator) {
            return #Err(#InvalidOperator);
        };

        // Update the new operator to the token
        switch (tokens.get(tokenId)) {
            case (?info) {
                info.operator := ?operator;
                tokens.put(tokenId, info);
            };
            case _ {
                return #Err(#TokenNotExist);
            };
        };


        switch (users.get(operator)) {
            case (?user) {
                user.allowedTokens := TrieSet.put(user.allowedTokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(operator, user);
            };
            case _ {
                let user = _newUser();
                user.allowedTokens := TrieSet.put(user.allowedTokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(operator, user);
            };
        };
        let txid = addTxRecord(msg.caller, #approve, ?tokenId, #user(msg.caller), #user(operator), Time.now());
        return #Ok(txid);
    };

    // set a operator can manage all of the owner's assets
    public shared(msg) func setApprovalForAll(operator: Principal, value: Bool): async TxReceipt {

        if(msg.caller == operator) {
            return #Err(#Unauthorized);
        };
        var txid = 0;
        if value {
            let caller = switch (users.get(msg.caller)) {
                case (?user) { user };
                case _ { _newUser() };
            };
            caller.operators := TrieSet.put(caller.operators, operator, Principal.hash(operator), Principal.equal);
            users.put(msg.caller, caller);
            let user = switch (users.get(operator)) {
                case (?user) { user };
                case _ { _newUser() };
            };
            user.allowedBy := TrieSet.put(user.allowedBy, msg.caller, Principal.hash(msg.caller), Principal.equal);
            users.put(operator, user);
            txid := addTxRecord(msg.caller, #approveAll, null, #user(msg.caller), #user(operator), Time.now());
        } else {
            switch (users.get(msg.caller)) {
                case (?user) {
                    user.operators := TrieSet.delete(user.operators, operator, Principal.hash(operator), Principal.equal);    
                    users.put(msg.caller, user);
                };
                case _ { };
            };
            switch (users.get(operator)) {
                case (?user) {
                    user.allowedBy := TrieSet.delete(user.allowedBy, msg.caller, Principal.hash(msg.caller), Principal.equal);    
                    users.put(operator, user);
                };
                case _ { };
            };
            txid := addTxRecord(msg.caller, #revokeAll, null, #user(msg.caller), #user(operator), Time.now());
        };
        return #Ok(txid);
    };

    //only owner can use transfer
    public shared(msg) func transfer(to: Principal, tokenId: Nat): async TxReceipt {
        var owner: Principal = switch (_ownerOf(tokenId)) {
            case (?own) {
                own;
            };
            case (_) {
                return #Err(#TokenNotExist)
            }
        };

        if (owner != msg.caller) {
            return #Err(#Unauthorized);
        };

        _clearApproval(msg.caller, tokenId);
        _transfer(to, tokenId);
        let txid = addTxRecord(msg.caller, #transfer, ?tokenId, #user(msg.caller), #user(to), Time.now());
        return #Ok(txid);
    };

    //owner and operator can use transferFrom
    public shared(msg) func transferFrom(from: Principal, to: Principal, tokenId: Nat): async TxReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        if(_isApprovedOrOwner(msg.caller, tokenId) == false) {
            return #Err(#Unauthorized);
        };
        _clearApproval(from, tokenId);
        _transfer(to, tokenId);
        let txid = addTxRecord(msg.caller, #transferFrom, ?tokenId, #user(from), #user(to), Time.now());
        return #Ok(txid);
    };

    // public shared(msg) func batchTransferFrom(from: Principal, to: Principal, tokenIds: [Nat]): async TxReceipt {
    //     var num: Nat = 0;
    //     label l for(tokenId in Iter.fromArray(tokenIds)) {
    //         if(_exists(tokenId) == false) {
    //             continue l;
    //         };
    //         if(_isApprovedOrOwner(msg.caller, tokenId) == false) {
    //             continue l;
    //         };
    //         _clearApproval(from, tokenId);
    //         _transfer(to, tokenId);
    //         num += 1;
    //         ignore addTxRecord(msg.caller, #transferFrom, ?tokenId, #user(from), #user(to), Time.now());
    //     };
    //     return #Ok(txs.size() - num);
    // };

    // public query function 
    public query func logo(): async Text {
        return logo_;
    };

    public query func name(): async Text {
        return name_;
    };

    public query func symbol(): async Text {
        return symbol_;
    };

    public query func desc(): async Text {
        return desc_;
    };

    public query func balanceOf(who: Principal): async Nat {
        return _balanceOf(who);
    };

    public query func totalSupply(): async Nat {
        return totalSupply_;
    };

    // get metadata about this NFT collection
    public query func getMetadata(): async Metadata {
        {
            logo = logo_;
            name = name_;
            symbol = symbol_;
            desc = desc_;
            totalSupply = totalSupply_;
            owner = owner_;
            cycles = Cycles.balance(); //@Itoka
            custodians = TrieSet.toArray(custodians);//@Itoka
            created_at = created_at; //@Itoka
            upgraded_at = upgraded_at; //@Itoka
            transactionFee = transcationFee_; //@Itoka
        }
    };

    public query func isApprovedForAll(owner: Principal, operator: Principal) : async Bool {
        return _isApprovedForAll(owner, operator);
    };

    public query func getOperator(tokenId: Nat) : async Principal {
        switch (_exists(tokenId)) {
            case true {
                switch (_getApproved(tokenId)) {
                    case (?who) {
                        return who;
                    };
                    case (_) {
                        return Principal.fromText("aaaaa-aa");
                    };
                }   
            };
            case (_) {
                throw Error.reject("token not exist")
            };
        }
    };

    public query func getUserInfo(who: Principal) : async UserInfoExt {
        switch (users.get(who)) {
            case (?user) {
                return _userInfotoExt(user)
            };
            case _ {
                throw Error.reject("unauthorized");
            };
        };        
    };

    public query func getUserTokens(owner: Principal) : async [TokenInfoExt] {
        let tokenIds = switch (users.get(owner)) {
            case (?user) {
                TrieSet.toArray(user.tokens)
            };
            case _ {
                []
            };
        };
        var ret: [TokenInfoExt] = [];
        for(id in Iter.fromArray(tokenIds)) {
            ret := Array_append(ret, [_tokenInfotoExt(_unwrap(tokens.get(id)))]);
        };
        return ret;
    };

    public query func ownerOf(tokenId: Nat): async Principal {
        switch (_ownerOf(tokenId)) {
            case (?owner) {
                return owner;
            };
            case _ {
                throw Error.reject("token not exist")
            };
        }
    };

    public query func getTokenInfo(tokenId: Nat) : async TokenInfoExt {
        switch(tokens.get(tokenId)){
            case(?tokeninfo) {
                return _tokenInfotoExt(tokeninfo);
            };
            case(_) {
                throw Error.reject("token not exist");
            };
        };
    };

    // Optional
    public query func getAllTokens() : async [TokenInfoExt] {
        Iter.toArray(Iter.map(tokens.entries(), func (i: (Nat, TokenInfo)): TokenInfoExt {_tokenInfotoExt(i.1)}))
    };

    //@Itoka
    public query func getAllHolders(): async [Principal] {
        let temp:[Principal] = Iter.toArray(Iter.map(tokens.entries(), func (i: (Nat, TokenInfo)): Principal {_tokenInfotoExt(i.1).owner}));
        return TrieSet.toArray(TrieSet.fromArray(temp,Principal.hash,Principal.equal));
    };

    public query func historySize(): async Nat {
        return txs.size();
    };

    public query func getTransaction(index: Nat): async TxRecord {
        return txs[index];
    };

    public query func getTransactions(start: Nat, limit: Nat): async [TxRecord] {
        var res: [TxRecord] = [];
        var i = start;
        while (i < start + limit and i < txs.size()) {
            res := Array_append(res, [txs[i]]);
            i += 1;
        };
        return res;
    };

    public query func getUserTransactionAmount(user: Principal): async Nat {
        var res: Nat = 0;
        for (i in txs.vals()) {
            if (i.caller == user or i.from == #user(user) or i.to == #user(user)) {
                res += 1;
            };
        };
        return res;
    };

    public query func getUserTransactions(user: Principal, start: Nat, limit: Nat): async [TxRecord] {
        var res: [TxRecord] = [];
        var idx = 0;
        label l for (i in txs.vals()) {
            if (i.caller == user or i.from == #user(user) or i.to == #user(user)) {
                if(idx < start) {
                    idx += 1;
                    continue l;
                };
                if(idx >= start + limit) {
                    break l;
                };
                res := Array_append<TxRecord>(res, [i]);
                idx += 1;
            };
        };
        return res;
    };
 
    // **********************************************
    // ********** Itoka Streaming Protocol **********
    // ********************Begin*********************
    type AudioLocation = Types.AudioLocation;
    type AlbumCoverLocation = Types.AlbumCoverLocation;
    type DecryptionKey = Types.DecryptionKey;
    type UpgradeHistory = Types.UpgradeHistory;
    private stable var streamingHistory: [TxRecord] = [];
    private stable var musicSetupHistory: [TxRecord] = [];
    private stable var upgradeHistory: [TxRecord] = [];

    private stable var streamingIndex: Nat = 0;
    private stable var musicSetupIndex: Nat = 0;
    private stable var upgradeIndex: Nat = 0;

    private stable var created_at: Time.Time = Time.now();
    private var upgraded_at: Time.Time = Time.now();

    private stable var decryptionKeyEntries : [(Nat, DecryptionKey)] = [];
    private stable var mp3FullAudioSrcEntires : [(Nat, Text)] = [];
    private stable var mp3PreviewAudioSrcEntires : [(Nat, Text)] = [];
    private stable var wavAudioSrcEntires : [(Nat, Text)] = [];

    private var decryptionKeys = HashMap.HashMap<Nat, DecryptionKey>(1, Nat.equal, Hash.hash);
    private var mp3FullAudioSrc = HashMap.HashMap<Nat, Text>(1, Nat.equal, Hash.hash);
    private var mp3PreviewAudioSrc = HashMap.HashMap<Nat, Text>(1, Nat.equal, Hash.hash);
    private var wavAudioSrc = HashMap.HashMap<Nat, Text>(1, Nat.equal, Hash.hash);

    //The transcation fee and streaming royalty are just place holders at this moment. We intergrate the these parts later.
    private stable var transcationFee_ : Nat = 0;
    switch _transcationFee {
      case null { transcationFee_ := 0 };
      case (?_transcationFee) { transcationFee_ := _transcationFee};
    };

    public type CustodianSetupReceipt = {
        #Ok: Text;
        #Err: Text;
    };

    public type MusicSetupReceipt = {
        #Ok: (Nat,Text);
        #Err: Errors;
    };

    public type DecryptionKeyReceipt = {
        #Ok: ?DecryptionKey;
        #Err: Errors;
    };

    public type StreamingReceipt = {
        #Ok: StreamingResult;
        #Err: Errors;
    };


    public type StreamingResult = {
        #AudioSrc: ?Text;
        #StreamingTimes: Nat;
    };



    private func _isAnonymous(caller: Principal): Bool {
        Principal.equal(caller, Principal.fromText("2vxsx-fae"))
    };

    private func _isCustodian(principal: Principal): Bool {
        return TrieSet.mem(custodians, principal, Principal.hash(principal), Principal.equal);
    };

    //For upgrade automatic recording
    private func _commit(_message:Text) {

        let upgradeHistory:UpgradeHistory ={
            message = _message;
            upgrade_time = upgraded_at;
        };

        let txid = addUpgradeRecord(msg.caller, #upgrade, null, #user(msg.caller), #commit(upgradeHistory), upgraded_at);  
    };
    

    private func addStreamingRecord(
        caller: Principal, op: Operation, tokenIndex: ?Nat,
        from: Record, to: Record, timestamp: Time.Time
    ): Nat {
        let record: TxRecord = {
            caller = caller;
            op = op;
            index = streamingIndex;
            tokenIndex = tokenIndex;
            from = from;
            to = to;
            timestamp = timestamp;
        };
        streamingHistory := Array_append(streamingHistory, [record]);
        streamingIndex += 1;
        return streamingIndex - 1;
    };

    private func addMusicSetupRecord(
        caller: Principal, op: Operation, tokenIndex: ?Nat,
        from: Record, to: Record, timestamp: Time.Time
    ): Nat {
        let record: TxRecord = {
            caller = caller;
            op = op;
            index = musicSetupIndex;
            tokenIndex = tokenIndex;
            from = from;
            to = to;
            timestamp = timestamp;
        };
        musicSetupHistory := Array_append(musicSetupHistory, [record]);
        musicSetupIndex += 1;
        return musicSetupIndex - 1;
    };

    private func addUpgradeRecord(
        caller: Principal, op: Operation, tokenIndex: ?Nat,
        from: Record, to: Record, timestamp: Time.Time
    ): Nat {
        let record: TxRecord = {
            caller = caller;
            op = op;
            index = upgradeIndex;
            tokenIndex = tokenIndex;
            from = from;
            to = to;
            timestamp = timestamp;
        };
        upgradeHistory := Array_append(upgradeHistory, [record]);
        upgradeIndex += 1;
        return upgradeIndex - 1;
    };

    //Upgrade management. The controllers and custodians are highly encourage to commit a short description for recent upgrade.   
    public shared(msg) func commit(_message:Text) : async MusicSetupReceipt {
        // only canister owner can upgrade
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let upgradeHistory:UpgradeHistory ={
            message = _message;
            upgrade_time = upgraded_at;
        };

        let txid = addUpgradeRecord(msg.caller, #upgrade, null, #user(msg.caller), #commit(upgradeHistory), Time.now());  
        return #Ok((txid,_message));
    };
 
    //Custodians management
    public shared (msg) func addCustodian(new_custodian:Principal) : async CustodianSetupReceipt {
        if(not _isCustodian(msg.caller)){
            return #Err("Unauthorized");
        }else if(_isCustodian(new_custodian)){
            return #Err("The object has already existed");
        }else{
            custodians := TrieSet.put(custodians,new_custodian,Principal.hash(new_custodian),Principal.equal);
            return #Ok(Principal.toText(new_custodian));
        }
    };

    public shared (msg) func removeCustodian(removed_custodian:Principal) : async CustodianSetupReceipt {
        if(not _isCustodian(msg.caller)){
            return #Err("Unauthorized");
        }else if(not _isCustodian(removed_custodian)){
            return #Err("The object does not exist");
        }
        else
        {
            custodians := TrieSet.delete(custodians,removed_custodian,Principal.hash(removed_custodian),Principal.equal);
            return #Ok(Principal.toText(removed_custodian));
        }
    };

    //only canister owner can set. Us TxRecord
    public shared(msg) func setTranscationFee(_transcationFee:Nat):async TxReceipt {
        if(not _isCustodian(msg.caller)){
            return #Err(#Unauthorized);
        };
        let old_transcationFee = transcationFee_;
        transcationFee_ := _transcationFee;
        let txid = addTxRecord(msg.caller, #setTranscationFee, null, #transcationFee(old_transcationFee), #transcationFee(transcationFee_), Time.now());
        return #Ok(txid);
    };


    //Set up music src
    public shared(msg) func setAudioPreviewSrc(tokenId: Nat, src:Text) : async MusicSetupReceipt {
        //mp3 preview
        // only canister owner can set
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };

        let source: Text = src;
        let token = _unwrap(tokens.get(tokenId));
        mp3PreviewAudioSrc.put(tokenId, source);

        let txid = addMusicSetupRecord(msg.caller, #setAudioPreviewSrc, ?token.index, #secret(""), #secret(""), Time.now());  
        return #Ok((txid,"#setAudioPreviewSrc"));
    };

    public shared(msg) func setAudioCompressedSrc(tokenId: Nat, src:Text) : async MusicSetupReceipt {
        // only canister owner can set
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };

        let source: Text = src;

        let token = _unwrap(tokens.get(tokenId));
        mp3FullAudioSrc.put(tokenId, source);

        let txid = addMusicSetupRecord(msg.caller, #setAudioCompressedSrc, ?token.index, #secret(""), #secret(""), Time.now());  
        return #Ok((txid,"#setAudioCompressedSrc"));
    };

    public shared(msg) func setAudioRawSrc(tokenId: Nat, src:Text) : async MusicSetupReceipt {
        //wav
        // only canister owner can set
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };

        let source: Text = src;

        let token = _unwrap(tokens.get(tokenId));
        wavAudioSrc.put(tokenId, source);

        let txid = addMusicSetupRecord(msg.caller, #setAudioRawSrc, ?token.index, #secret(""), #secret(""), Time.now());  
        return #Ok((txid,"#setAudioRawSrc"));
    };

    //@Itoka: Set decryption key to decode json file back to audio file 
    public shared(msg) func setDecryptionKey(tokenId: Nat, _iv: Text, _privateKey:Text) : async MusicSetupReceipt {
        // only canister owner can set
        if(not _isCustodian(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };
        let decryptionKey: DecryptionKey = {
            iv=_iv; 
            privateKey=_privateKey;
        };
        let token = _unwrap(tokens.get(tokenId));
        decryptionKeys.put(tokenId, decryptionKey);

        let txid = addMusicSetupRecord(msg.caller, #setDecryptionKey, ?token.index, #secret(""), #secret(""), Time.now());  
        return #Ok((txid,"#setDecryptionKey"));
    };

    // [Retrival functions] Retrival functions are not getter query functions, since retrival operation will make record and written on blockchain.
    // Preview retrival requirement
    // caller: anyone, any platform -> (future upgrade to non-anonymous)
    // listener: anyone  
    public shared(msg) func retriveAudioPreviewSrc(tokenId: Nat, listener:Principal) : async StreamingReceipt{
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };

        let token = _unwrap(tokens.get(tokenId));
        let audioSrc = mp3PreviewAudioSrc.get(tokenId);
        let txid = addStreamingRecord(msg.caller, #retriveAudioPreviewSrc, ?token.index, #user(token.owner), #user(listener), Time.now()); 
        return #Ok(#AudioSrc(audioSrc));
    };

    // full mp3 retrival requirement
    // caller: non-anonymous -> (future upgrade to owner and operator)
    // listener: non-anonymous -> (future upgrade to authorized listener)
    public shared(msg) func retriveAudioCompressedSrc(tokenId: Nat, listener:Principal) : async StreamingReceipt{
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };
        // Caller can not be anonymous
        if(_isAnonymous(msg.caller) == true) {
            return #Err(#Unauthorized);
        };
        // listener Caller can not be anonymous
        if(_isAnonymous(listener) == true) {
            return #Err(#Unauthorized);
        };

        let token = _unwrap(tokens.get(tokenId));
        let audioSrc = mp3FullAudioSrc.get(tokenId);
        let txid = addStreamingRecord(msg.caller, #retriveAudioCompressedSrc, ?token.index, #user(token.owner), #user(listener), Time.now()); 
        return #Ok(#AudioSrc(audioSrc));
    };

    // raw retrival requirement
    // caller: owner and custodian -> (future upgrade to owner and operator)
    // listener: non-anonymous -> (future upgrade to authorized listener)
    public shared(msg) func retriveRawAudioSrc(tokenId: Nat, listener:Principal) : async StreamingReceipt{
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };
        // Only custodian and owner can stream the raw
        if(_isCustodian(msg.caller)==false or _isOwner(msg.caller, tokenId) == false) {
            return #Err(#Unauthorized);
        };
        // listener must have identity
        if(_isAnonymous(listener) == true) {
            return #Err(#Unauthorized);
        };

        let token = _unwrap(tokens.get(tokenId));
        let audioSrc = wavAudioSrc.get(tokenId);
        let txid = addStreamingRecord(msg.caller, #retriveAudioRawSrc, ?token.index, #user(token.owner), #user(listener), Time.now()); 
        return #Ok(#AudioSrc(audioSrc));
    };

    // retrive decryption key to decode json file back to audio file. Only owner can get the decryption key
    public shared(msg) func retriveDecryptionKey(tokenId: Nat) : async DecryptionKeyReceipt{
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist);
        };
        if(_isOwner(msg.caller, tokenId) == false) {
            return #Err(#Unauthorized);
        };

        let token = _unwrap(tokens.get(tokenId));
        let key = decryptionKeys.get(tokenId);
        let txid = addStreamingRecord(msg.caller, #retriveDecryptionKey, ?token.index, #user(token.owner), #user(msg.caller), Time.now()); 
        return #Ok(key);
    };



    // Query
    public query func who_are_custodians() : async [Principal] {
        return TrieSet.toArray(custodians);
    };

    public query func historySize_streaming(): async Nat {
        return streamingHistory.size();
    };

    public query func getStreamingHistory(index: Nat): async TxRecord {
        return streamingHistory[index];
    };

    public query func getLatestStreamingHistory(): async TxRecord {
        return streamingHistory[streamingHistory.size()-1];
    };

    public query func getLatestMusicSetupHistory(): async TxRecord {
        return musicSetupHistory[musicSetupHistory.size()-1];
    };

    public query func getLatestUpgradeHistory(): async TxRecord {
        return upgradeHistory[upgradeHistory.size()-1];
    };

    public query func getStreamingHistorys(start: Nat, limit: Nat): async [TxRecord] {
        var res: [TxRecord] = [];
        var i = start;
        while (i < start + limit and i < streamingHistory.size()) {
            res := Array_append(res, [streamingHistory[i]]);
            i += 1;
        };
        return res;
    };


    public query func getTokenAudioPreviewStreamingAmount(tokenId: Nat): async StreamingReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        var res: Nat = 0;        
        for (i in streamingHistory.vals()) {
            if ( _unwrap(i.tokenIndex) == tokenId) {
                if (i.op == #retriveAudioPreviewSrc)
                {
                    res += 1;
                };
            };
        };
        return #Ok(#StreamingTimes(res));
    };

    public query func getTokenAudioCompressedStreamingAmount(tokenId: Nat): async StreamingReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        var res: Nat = 0;        
        for (i in streamingHistory.vals()) {
            if ( _unwrap(i.tokenIndex) == tokenId) {
                if (i.op == #retriveAudioCompressedSrc)
                {
                    res += 1;
                };
            };
        };
        return #Ok(#StreamingTimes(res));
    };

    public query func getTokenAudioRawStreamingAmount(tokenId: Nat): async StreamingReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        var res: Nat = 0;        
        for (i in streamingHistory.vals()) {
            if ( _unwrap(i.tokenIndex) == tokenId) {
                if (i.op == #retriveAudioRawSrc)
                {
                    res += 1;
                };
            };
        };
        return #Ok(#StreamingTimes(res));
    };

    public query func getTokenAudioTotalStreamingAmount(tokenId: Nat): async StreamingReceipt {
        if(_exists(tokenId) == false) {
            return #Err(#TokenNotExist)
        };
        var res: Nat = 0;        
        for (i in streamingHistory.vals()) {
            if ( _unwrap(i.tokenIndex) == tokenId) {
                if (i.op == #retriveAudioPreviewSrc or i.op == #retriveAudioCompressedSrc or i.op == #retriveAudioRawSrc)
                {
                    res += 1;
                };
            };
        };
        return #Ok(#StreamingTimes(res));
    };

    public query func getAllTokenAudioTotalStreamingAmount(): async StreamingReceipt {

        var res: Nat = 0;        
        for (i in streamingHistory.vals()) {
            if (i.op == #retriveAudioPreviewSrc or i.op == #retriveAudioCompressedSrc or i.op == #retriveAudioRawSrc)
            {
                res += 1;
            };
        };
        return #Ok(#StreamingTimes(res));
    };


    // Check a NFT holder how many times his all NFTs were streamed -> (Need to upgrade the full mp3 or raw condition since preview's caller is not bounded)
    public query func getHolderStreamingAmount(user: Principal): async Nat {
        var res: Nat = 0;
        for (i in streamingHistory.vals()) {
            if ( i.from == #user(user)) {
                res += 1;
            };
        };
        return res;
    };

    // Check a user how many times he listened to music -> (Need to upgrade the full mp3 or raw condition since preview's caller is not bounded)
    public query func getUserlisteningAmount(user: Principal): async Nat {
        var res: Nat = 0;
        for (i in streamingHistory.vals()) {
            if (i.to == #user(user)) {
                res += 1;
            };
        };
        return res;
    };

    public query func getUserStreamingHistorys(user: Principal, start: Nat, limit: Nat): async [TxRecord] {
        var res: [TxRecord] = [];
        var idx = 0;
        label l for (i in streamingHistory.vals()) {
            if (i.from == #user(user)) {
                if(idx < start) {
                    idx += 1;
                    continue l;
                };
                if(idx >= start + limit) {
                    break l;
                };
                res := Array_append<TxRecord>(res, [i]);
                idx += 1;
            };
        };
        return res;
    };
    
    public query func getUserlistenings(user: Principal, start: Nat, limit: Nat): async [TxRecord] {
        var res: [TxRecord] = [];
        var idx = 0;
        label l for (i in streamingHistory.vals()) {
            if (i.to == #user(user)) {
                if(idx < start) {
                    idx += 1;
                    continue l;
                };
                if(idx >= start + limit) {
                    break l;
                };
                res := Array_append<TxRecord>(res, [i]);
                idx += 1;
            };
        };
        return res;
    };
    
    public query func getAllMusicSetupHistory(): async [TxRecord] {
        var res: [TxRecord] = [];
        var i = 0;
        while (i < musicSetupHistory.size()) {
            res := Array_append(res, [musicSetupHistory[i]]);
            i += 1;
        };
        return res;
    };

    public query func getAllUpgradeHistory(): async [TxRecord] {
        var res: [TxRecord] = [];
        var i = 0;
        while (i < upgradeHistory.size()) {
            res := Array_append(res, [upgradeHistory[i]]);
            i += 1;
        };
        return res;
    };

    public query func getTranscationFee(): async Nat {
        return transcationFee_;
    };

    // ********************END***********************
    // ********** Itoka Streaming Protocol **********
    // **********************************************

    //@Itoka Upgrade functions
    system func preupgrade() {
        usersEntries := Iter.toArray(users.entries());
        tokensEntries := Iter.toArray(tokens.entries());
        custodiansEntries := TrieSet.toArray(custodians);
        decryptionKeyEntries := Iter.toArray(decryptionKeys.entries());

        mp3FullAudioSrcEntires := Iter.toArray(mp3FullAudioSrc.entries());
        mp3PreviewAudioSrcEntires := Iter.toArray(mp3PreviewAudioSrc.entries());
        wavAudioSrcEntires := Iter.toArray(wavAudioSrc.entries());

    };

    system func postupgrade() {
        type TokenInfo = Types.TokenInfo;
        type UserInfo = Types.UserInfo;
        type DecryptionKey = Types.DecryptionKey;


        mp3FullAudioSrc := HashMap.fromIter<Nat, Text>(mp3FullAudioSrcEntires.vals(), 1, Nat.equal, Hash.hash);
        mp3PreviewAudioSrc := HashMap.fromIter<Nat, Text>(mp3PreviewAudioSrcEntires.vals(), 1, Nat.equal, Hash.hash);
        wavAudioSrc := HashMap.fromIter<Nat, Text>(wavAudioSrcEntires.vals(), 1, Nat.equal, Hash.hash);

        users := HashMap.fromIter<Principal, UserInfo>(usersEntries.vals(), 1, Principal.equal, Principal.hash);
        tokens := HashMap.fromIter<Nat, TokenInfo>(tokensEntries.vals(), 1, Nat.equal, Hash.hash);
        custodians := TrieSet.fromArray<Principal>(custodiansEntries,Principal.hash,Principal.equal);
        decryptionKeys := HashMap.fromIter<Nat, DecryptionKey>(decryptionKeyEntries.vals(), 1, Nat.equal, Hash.hash); 

        usersEntries := [];
        tokensEntries := [];
        custodiansEntries := [];
        decryptionKeyEntries := [];

        upgraded_at := Time.now();

        _commit("UPGRADE [AUTO RECORDING]")

    };

    public query func availableCycles() : async Nat {
        return Cycles.balance();
    };

};
