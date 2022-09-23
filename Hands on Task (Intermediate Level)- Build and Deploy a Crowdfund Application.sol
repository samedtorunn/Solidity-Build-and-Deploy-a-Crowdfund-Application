// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; // solidity version is declared.

interface IERC20 {
    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);
}

contract CrowdFund { // a crowdfunding contract is created. 


    event Launch( // launch detailes are defined with the related info. 
        uint id,
        address indexed owner,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );

    // basic event operations are defined to inform the calling application about the current state of the contract,
    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);

    struct Campaign { // a basic campaign structure is defined here.
       
        address owner; // to store the owner
        
        uint goal; // how many tokens needed to achieve the goal.
        
        uint pledged; //how many tokens are pledged.

        uint32 startAt; // this will be the time when the campaign starts.
        
        uint32 endAt; // this will be the time when the campaign ends.
        
        bool claimed; // this boolean will decide if the pledged amount is claimable or not.
    }


    IERC20 public immutable token; // a token is declared.

    uint public count; // this counter will be counting the campaigns, plus it will help to define ids.
    
    mapping(uint => Campaign) public campaigns; // campaigns are stored with campaign ids in this mapping.

    
    mapping(uint => mapping(address => uint)) public pledgedAmount; // mapping of how many tokens are pledged to a campaign by a specific address

    constructor(address _token) { // constructor with the token address
        token = IERC20(_token);
    }

    function launch(
        uint _goal,
        uint32 _startAt,
        uint32 _endAt      
    ) external {
        require(_startAt >= block.timestamp, "start at < now"); // starting point is defined.
        require(_endAt >= _startAt, "end at < start at"); // starting time should be earlier than ending time.
        require(_endAt <= block.timestamp + 90 days, "end at > max duration"); // max campaign duration is 90 days.

        count += 1; // everytime a campaign is launched, count goes up by 1.
        campaigns[count] = Campaign({ // stored the campaign details to be launched.
            owner: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function cancel(uint _id) external { // cancel function
        Campaign memory campaign = campaigns[_id];
        require(campaign.owner == msg.sender, "not the owner");
        require(block.timestamp < campaign.startAt, "started");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge(uint _id, uint _amount) external { // this function provides to donate tokens to the campaign.
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not started");
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(campaign.owner == msg.sender, "not the owner");
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.transfer(campaign.owner, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "pledged >= goal");

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
