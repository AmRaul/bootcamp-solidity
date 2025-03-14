// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Elaction {
    string[] public electors;
    // ["Pasha","Sasha","Dasha","Masha"]
    address public owner;

    uint256 public maxVoters;

    uint256 public votersCount;

    uint256 public electionTime;

    uint256 public electionTimeEnd;

    mapping(address => bool) public userVotes;

    mapping(uint256 => uint256) public numberOfVotes;

    event voted(uint256 _index, address _voter);
    event voteStoped();
    event voteChange();

    error OnlyOwnerAllowed();
    error ElectorDoesNotExist(uint256 _pickedElector, uint256 _totaElectors);
    error OwnerCantVote();
    error CantVoteTwice();
    error MaxVotesReached(uint256 _maxVoters);
    error VotingIsOver();
    error MaxVotesCantDecrease();
    error MustBeLater();

    modifier onlyOwner() {
        require(owner == msg.sender, OnlyOwnerAllowed());
        _;
    }


    function getLeader() public view returns(uint256) {
        uint256 leaderIndex;

        for(uint i = 0; i < electors.length; i++) {
            if(numberOfVotes[leaderIndex] < numberOfVotes[i]) {
                leaderIndex = i;
            }
        }

        return leaderIndex;
    }

    function vote(uint256 _number) public {
        require(block.timestamp < electionTimeEnd, VotingIsOver());
        require(userVotes[msg.sender]==false, CantVoteTwice());
        require(_number< electors.length, ElectorDoesNotExist(_number, electors.length));
        require(votersCount < maxVoters, MaxVotesReached(maxVoters));
        require(owner != msg.sender, OwnerCantVote());

        userVotes[msg.sender] = true;
        numberOfVotes[_number] += 1;
        votersCount ++;

        emit voted(_number, msg.sender);
    }

    function endElection() public onlyOwner {
        electionTimeEnd = block.timestamp;

        emit voteStoped();
    }

    function resetMaxVotes(uint256 _newMaxVotes) public onlyOwner {
        require(_newMaxVotes > maxVoters, MaxVotesCantDecrease());
        maxVoters = _newMaxVotes;

        emit voteChange();
    }

    function resetEndTime(uint256 _newEndTime) public onlyOwner {
        require(electionTimeEnd < _newEndTime, MustBeLater());
        electionTimeEnd = block.timestamp + _newEndTime;

        emit voteChange();
    }

}



    

    
