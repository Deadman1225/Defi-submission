// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

contract Main
{

    function sqrt(uint256 y) internal pure returns(uint256 z)
    {
        if(y > 3)
        {
            z = y;
            uint256 x = y / 2 + 1;

            while(x < z)
            {
                z = x;
                x = (y / x + x) / 2;
            }
        }
        else if(y != 0)
        {
            z = 1;
        }
    }


    //to check for same title by converting to lower case
    function toLowerCase(string memory str) internal pure returns (string memory) 
    {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
    
        for (uint i = 0; i < bStr.length; i++) 
        {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) 
            {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            }
            else 
            {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    address public admin;
    uint256 public constant threshold = 1200;///15 level 3 contributions

    struct Credential
    {
        string title;
        uint level;
        uint timestamp;
    }   

    modifier onlyAdmin()
    {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    /*
        Credentials are non-transferable because they are stored permanently 
        under a wallet address and no function exists to move them between addresses.

        This preserves integrity of reputation since a user cannot sell, buy, 
        or transfer contribution history.
    */

    mapping(address => Credential[]) private credential;
    mapping(address => mapping(string => bool)) private hasReceivedTitle;

    function issueContribution(address user, string calldata title, uint level) external onlyAdmin
    {   
        require(level >= 1 && level <= 3, "Level must be between 1 and 3");

        /*
            We reject the same title credential as it could potentially lead to a way 
            of doing very easy level task and accumulating more and more points
            which is unfair.
        */

        string memory sanitizeTitle = toLowerCase(title);
        require(!hasReceivedTitle[user][sanitizeTitle], "Title already exists");
        credential[user].push(
            Credential(
                {
                    title : title,
                    level : level,
                    timestamp : block.timestamp
                })
        );

        hasReceivedTitle[user][sanitizeTitle] = true;
    }



    /*
        The current formula for calculating trust score is as follows: 
        1. We calculate the average but multiply it with since we cant store floats
            Average = ((Total Level + 30) / (Total Length + 15)) * 100
            I have used 30 in the numerator and 15 in the denominator to smooth the first few values out
            since one or two length credential can be vague we use the constant of 30 as in 15 contribution of 
            level 2 to balance things out.
            Eg - A user with one contribution of value 3 without those values has score = 900
                 A user with those values has score = 375.39 which is much better for comparison with others

            Total Level here is sum of all the levels 
        
        2. We calculate another value called as weighted average which is :
                Weighted average = (Average * Average) / 100
        
        3. After this we do Score = Weighted Average * (length)^1/4 or sqrt(sqrt(length))

        I originally wanted to use Score = Weighted Average * ln(length + 1) 
        but ln is no there in solidity so had to use (length)^1/4
    */

    function calculateTrustScore(address user) public view returns (uint256)
    {
        uint256 score = 0;

        uint length = credential[user].length;
        uint totalLevel = 0;

 
        for(uint index = 0; index < credential[user].length; index++)
        {
            totalLevel += credential[user][index].level;
        }

        uint256 average = ((totalLevel + 30) * 100) / (length + 15);

        uint256 weightedAverage = average * average / 100;

        score = weightedAverage * sqrt(sqrt((length)));
        return score;
    }

    function accessGranted() public view returns(bool)
    {
        require(calculateTrustScore(msg.sender) >= threshold, "Trust Score below the threshold");
        return true;
    }

    function getCredentials(address user) external view returns (Credential[] memory) 
    {
        return credential[user];
    }

    constructor()
    {
        admin = msg.sender;
    }
}
