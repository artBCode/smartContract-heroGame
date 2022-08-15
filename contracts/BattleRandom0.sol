pragma solidity ^0.8.0;

import "./Battle.sol";

pragma solidity ^0.8.0;

// BEWRAE!! DO NOT deploy this contract! It should be used just for testing.

// In this battle contract the random generator always returns 0. 
// This means: 
//   1. each character attribute gets the minimum value in the range, 
//   2. the attacker uses all his skills, 
//   3. the defender uses all his skills and gets lucky all the time which means his health never decreases.
contract BattleRandom0 is Battle {
    
    function randomUint() internal override pure returns (uint) {
        return 0;
    } 

    
}

