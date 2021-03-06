pragma solidity ^0.4.15;

contract Timed {
    modifier beforeTime(uint timestamp) {
        require(block.timestamp + 15*60 < timestamp);
        _;
    }
    
    modifier afterTime(uint timestamp) {
        require(block.timestamp + 15*60 > timestamp);
        _;
    }
}

contract Staked {
    modifier costs(uint price) {
        require(msg.value == price);
        _;
    }
}

contract Bond  is Timed, Staked {
  
    struct Friend {
        address friendAddr;
        bool hasVoted; //true if yetVoted
        bool voteCompleted; //true if vote completed for the user
    }
    
    struct Resolution {
        uint128 resolutionId; //unique id for each resolution
        address bonderAddress; //user who sets the resolution
        mapping (address => Friend) friendAddressMap;
        address[] friendsList; //all participating friends
        uint128 stake; //users stake;
        string message; //resolution text
        uint128 validationCount; //total count of friends who have validated results of the resolution
        uint128 validationTrueCount; //count of friends who validated as results as true
        uint128 endTime; //deadline for the resolutions
        bool completed; //resolution has finished
    }
    
    mapping (uint128  => Resolution) resolutions;
    uint128 public resolutionCount;
    
    //Events
    event ResolutionCreated(uint128 id);
    event VoteCreated(uint128 resId, bool vote);
    event ResolutionCompleted(uint128 id, bool won);
    
    //test addresses
    //"0x53d284357ec70ce289d6d64134dfac8e511c8a3d","0xbe0eb53f46cd790cd13851d5eff43d12404d33e8","0x3bf86ed8a3153ec933786a02ac090301855e576b","0x74660414dfae86b196452497a4332bd0e6611e82","0x847ed5f2e5dde85ea2b685edab5f1f348fb140ed"
    //get number of resolution and set resolutionId
    
    //assuming fe takes care of friend valiadation
    function addNewFriend(uint128 _tempID,address _friendAddr) private {
        resolutions[_tempID].friendAddressMap[_friendAddr].friendAddr = _friendAddr;
        resolutions[_tempID].friendAddressMap[_friendAddr].hasVoted = false;
        resolutions[_tempID].friendAddressMap[_friendAddr].voteCompleted = false;
        resolutions[_tempID].friendsList.push(_friendAddr);
    }
    
    
    function newResolution(
        string _message, 
        uint128 _stake,
        uint128 _endTime,
        address friend1, 
        address friend2, 
        address friend3, 
        address friend4, 
        address friend5) costs(_stake) payable public {
            
        uint128 tempID = uint128(resolutionCount);
        // resolutions[tempID].bonderAddress = 0x847ed5f2e5dde85ea2b685edab5f1f348fb140ed; //bonderAddress = msg.sender;
        
        resolutions[tempID].bonderAddress = msg.sender; //bonderAddress = msg.sender;
        
        addNewFriend(tempID, friend1);
        addNewFriend(tempID, friend2);
        addNewFriend(tempID, friend3);
        addNewFriend(tempID, friend4);
        addNewFriend(tempID, friend5);
      
        resolutions[tempID].resolutionId = tempID;
        resolutions[tempID].message = _message;
        resolutions[tempID].stake = _stake;
        resolutions[tempID].endTime = _endTime;
        ++resolutionCount;
        
        //Raise event when successfully added a new resolution
        ResolutionCreated(tempID);
    }
    
    //check if is valid friend
    function isFriend(uint128 resolutionId, address friendAddr) public returns (bool) {
         return resolutions[resolutionId].friendAddressMap[friendAddr].friendAddr != 0;
    }
    
    function getFriend(uint128 resolutionId, address friendAddr) public returns (address, bool, bool) {
        Friend memory friend = resolutions[resolutionId].friendAddressMap[friendAddr];
        return (friend.friendAddr, friend.hasVoted, friend.voteCompleted);
    }
    
    
    function makeVote(uint128 resolutionId, bool _voteCompleted) afterTime(resolutions[resolutionId].endTime) public {
        address curFriend = msg.sender;
        require(isFriend(resolutionId, curFriend)); //change to sender.address
        require(!resolutions[resolutionId].friendAddressMap[curFriend].hasVoted);
        
        resolutions[resolutionId].friendAddressMap[curFriend].voteCompleted = _voteCompleted;
        resolutions[resolutionId].friendAddressMap[curFriend].hasVoted = true;
        resolutions[resolutionId].validationCount += 1;
        if(_voteCompleted){
            ++resolutions[resolutionId].validationTrueCount;
        }
        
        VoteCreated(resolutionId, _voteCompleted);
    }
    
    //based on he gets a refund or not
    function isGettingStakeBack(uint128 resolutionId) private returns (bool) {
        return resolutions[resolutionId].validationTrueCount >= 3;
    } 
    
    //result abd pay    
    function finalResult(uint128 resolutionId) public returns (bool) {
        require(false == resolutions[resolutionId].completed);
        require(msg.sender == resolutions[resolutionId].bonderAddress);
        require(resolutions[resolutionId].validationTrueCount>=3 || resolutions[resolutionId].validationCount-resolutions[resolutionId].validationTrueCount>=3);
        bool result = isGettingStakeBack(resolutionId);
        //if bonder completed the resolutions
        if(result) {
            //send transaction back to resolutions[resolutionId].bonderAddress
            resolutions[resolutionId].bonderAddress.transfer(resolutions[resolutionId].stake);
        } else {
            uint shareToPay = resolutions[resolutionId].stake / resolutions[resolutionId].friendsList.length;
            for(uint128 i = 0; i < resolutions[resolutionId].friendsList.length; i++) {
                //pay resolution[resolutionId].friendVotedFalse[i] shareToPay Aion
                resolutions[resolutionId].friendsList[i].transfer(shareToPay);
            }
        }
        resolutions[resolutionId].completed = true;
        ResolutionCompleted(resolutionId, result);
    }
    
    //Getters
    function getResolution(uint128 resolutionId) public constant returns(uint128,address, string, uint128, uint128, address[], uint128, uint128, bool){
        Resolution storage resolution = resolutions[resolutionId];
        return(resolutionId,resolution.bonderAddress, resolution.message, resolution.stake, resolution.endTime, resolution.friendsList, resolution.validationCount, resolution.validationTrueCount, resolution.completed);
    }
    
    function getParticipatingResolutions(address addr) public constant returns (uint128[], bool[]){
        uint128 participationCount = 0;
        for(uint128 i=0; i<resolutionCount; i++){
            Resolution storage resolution = resolutions[i];
            if(resolution.bonderAddress == addr || resolution.friendAddressMap[addr].friendAddr!=0){
                participationCount+=1;
            }
        }
        uint128[] memory resolutionIds = new uint128[](participationCount);
        bool[] memory creatorFlag = new bool[](participationCount);
        for(uint128 j=0; j<resolutionCount; j++){
            Resolution storage resolution2 = resolutions[j];
            if(resolution2.bonderAddress == addr || resolution2.friendAddressMap[addr].friendAddr!=0){
                resolutionIds[participationCount-1] = j;
                creatorFlag[participationCount-1] = resolution2.bonderAddress == addr;
                participationCount-=1;
            }
        }
        return (resolutionIds, creatorFlag);
    }
}

  // ETH TEST
  //"todo",10000000000000000000, 1545082216,"0x14723a09acff6d2a60dcdf7aa4aff308fddc160c","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x583031d1113ad414f02576bd6afabfb302140225","0xdd870fa1b7c4700f2bd7f44238821c26f7392148","0xdd870fa1b7c4700f2bd7f44238821c26f7392148"
  //AION
  //"testing",10000000000000000000,1545082216,"0xa09866ac4d3a95614d5a36ecd59977d052684451839a6216f40023aeceae8dbc","0xa069e108b787ecd14c59b0f445e82b30c229e30cb654754d205ae0370c607fc4","0xa0f09de1e3ef119226dbc339dc55e8c5c360bda2cca906a5602f765ef13487ca","0xa0fda14b5d9419de84ba9b72d2cc3df29c54b7dcc5905a130de8c034d79e3187","0xa0f80633c1b64574751f0caea24809cf495faaea0443ad23325eb6fa7e0e8e06"