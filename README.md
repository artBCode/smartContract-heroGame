# SmartContract: Hero Game

In this project a smart contract is used to simulate a battle between a hero and a villain.

## The main languages, libraries and frameworks involved in this project

* solidity
* truffle

## Run the tests
```
truffle test
```

## How to play the game
The game can be played by invoking the `fight` function. 
A battle is made of multiple fights. A fight contains exactly one attack (attacker --> defender). In the next fight the defender becomes the attacker
and the attacker becomes the defender.

# How to check the outcome of each fight
Each `fight` invocation produces and event which can be found in the function result (logs).
```
emit BattleStep(address(this), // the battle address
                        currentTurnNumber, // the fight number
                        CharacterType.Hero == currentAttack.attacker.characterType, // the hero attacked in this fight 
                        currentAttack.attacker.health, // the health of the attacker after the fight
                        currentAttack.defender.health, // the health of the defender after the fight
                        currentAttack.damage, // the damage produced by the attacker to the defender
                        currentAttack.listAttackerUsedSkills, // the skills used by the attacker in this fight
                        currentAttack.listDefenderUsedSkills); // the skills used by the defender in this fight
```

## How to add a new NEW_ATTACK_SKILL
In order to add a new attack skill it should be added in:
```
enum AttackSkillKey {BasicStrike, SecondStrike, ThrirdStrike, NEW_ATTACK_SKILL_KEY}
```

define the skill:

```
// 55 is the probability of being used
// newSkillAvailabilityFunction is a function(to be defined) which returns true/false to indicate if the skill can be used in an ongoing attack
// newSkillActionFunction is a function(to be defined) which defines and extra action to be performed in an ongoing attack
Skill NEW_ATTACK_SKILL = Skill(55, newSkillAvailabilityFunction, newSkillActionFunction);
```


```
mapAttackSkill[AttackSkillKey.NEW_ATTACK_SKILL_KEY] = NEW_ATTACK_SKILL;
```

A similar procedure can be used to add a defence skill. 


## Further development
Create a game contract which deploys new instances of the Battle contract on demand.
This way, a user can create a new Battle and play it. (He pays for both the deployment and interaction with the new Battle) 
