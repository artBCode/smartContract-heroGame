pragma solidity ^0.8.0;

import "./Ownable.sol";

pragma solidity ^0.8.0;

// a battle can only be played by the creator 
contract Battle is Ownable {
    // using structs instead of contracts to save gas. Assumming code reusability and scalability is less important than gas cost. 
    uint8 constant HERO_HEALTH_MIN = 70;
    uint8 constant HERO_HEALTH_MAX = 100;
    uint8 constant HERO_STRENGTH_MIN = 70;
    uint8 constant HERO_STRENGTH_MAX = 80;
    uint8 constant HERO_DEFENCE_MIN = 45;
    uint8 constant HERO_DEFENCE_MAX = 55;
    uint8 constant HERO_SPEED_MIN = 40;
    uint8 constant HERO_SPEED_MAX = 50;
    uint8 constant HERO_LUCK_MIN = 10;
    uint8 constant HERO_LUCK_MAX = 30;

    uint8 constant VILLAIN_HEALTH_MIN = 60;
    uint8 constant VILLAIN_HEALTH_MAX = 90;
    uint8 constant VILLAIN_STRENGTH_MIN = 60;
    uint8 constant VILLAIN_STRENGTH_MAX = 90;
    uint8 constant VILLAIN_DEFENCE_MIN = 40;
    uint8 constant VILLAIN_DEFENCE_MAX = 60;
    uint8 constant VILLAIN_SPEED_MIN = 40;
    uint8 constant VILLAIN_SPEED_MAX = 60;
    uint8 constant VILLAIN_LUCK_MIN = 25;
    uint8 constant VILLAIN_LUCK_MAX = 40;

    uint8 constant BATTLE_MAX_NUM_TURNS = 20;

    enum AttackSkillKey {BasicStrike, SecondStrike, ThrirdStrike}
    enum DefenceSkillKey {BasicDefence, Resilience}
    enum CharacterType {Hero, Villain}
    struct Character {
        uint8 health;
        uint8 strength;
        uint8 defence;
        uint8 speed;
        uint8 luck;
        CharacterType characterType;
        AttackSkillKey[] attackSkills;
        DefenceSkillKey[] defenceSkills;
    
    }

    struct Skill {
        uint8 chanceOfBeingUsed; //from 0-100
        // function which tells if the skill is available for usage in this turn / strike
        function() internal returns(bool) available;
        // function which manipulates the currentAttack by performing the skill-specific action 
        function() internal action;
        
    }

    struct Attack {
        Character attacker;
        Character defender;
        AttackSkillKey[] listAttackerUsedSkills;
        DefenceSkillKey[] listDefenderUsedSkills;
        uint8 damage;
    }

    // these 2 lists store the skills used at each turn. Conceptually it should have been a list of sets, 
    // and without Solidity constrains they should have been included in the Attack struct. 
    mapping (AttackSkillKey => bool)[20] private attackerUsedSkills;
    mapping (DefenceSkillKey => bool)[20] private defenderUsedSkills;

    Skill SKILL_BASIC_STRIKE = Skill(100, alwaysAvailable, basicStrikeFunction);
    Skill SKILL_SECOND_STRIKE = Skill(10, alwaysAvailable, basicStrikeFunction);
    Skill SKILL_THIRD_STRIKE = Skill(1, availableThirdStrike, basicStrikeFunction);

    Skill SKILL_BASIC_DEFENCE = Skill(20, alwaysAvailable, basicDefenceFunction);
    Skill SKILL_RESILIENCE = Skill(20, availableResilience, resilienceFunction); // this one depends on the history

    enum BattleOutcome { InProgress, HeroWon, VillainWon, Draw }
    event BattleStep(address battleAddress, uint turnNumber, bool heroAttacked, uint attackerHealth, uint defenderHealth, uint8 damage, AttackSkillKey[] listAttackerUsedSkills, DefenceSkillKey[] listDefenderUsedSkills);

    mapping (AttackSkillKey => Skill) mapAttackSkill;
    mapping (DefenceSkillKey => Skill) mapDefenceSkill;

    // BEWARE! The Order of the keys is the order in which the skills are aplied in a battle
    // ATTENTION: ThrirdStrike should never be placed before SecondStrike
    AttackSkillKey[] private HERO_ATTACK_SKILLS = [AttackSkillKey.BasicStrike, AttackSkillKey.SecondStrike, AttackSkillKey.ThrirdStrike];
    DefenceSkillKey[] private HERO_DEFENCE_SKILLS = [DefenceSkillKey.BasicDefence, DefenceSkillKey.Resilience];

    AttackSkillKey[] private VILLAIN_ATTACK_SKILLS = [AttackSkillKey.BasicStrike];
    DefenceSkillKey[] private VILLAIN_DEFENCE_SKILLS = [DefenceSkillKey.BasicDefence];
    
    Character public heroInitialState;
    Character public villainInitialState;
    uint public currentTurnNumber;

    // storing all the attacks
    Attack[] previousAttacks;
    Attack currentAttack;

    BattleOutcome public battleOutcome;
    uint private randomNumberHelper;


    constructor() {
        initSkillMappings();
        heroInitialState = Character(randomInRange(HERO_HEALTH_MIN, HERO_HEALTH_MAX),
                        randomInRange(HERO_STRENGTH_MIN, HERO_STRENGTH_MAX),
                        randomInRange(HERO_DEFENCE_MIN, HERO_DEFENCE_MAX),
                        randomInRange(HERO_SPEED_MIN, HERO_SPEED_MAX), 
                        randomInRange(HERO_LUCK_MIN, HERO_LUCK_MAX),
                        CharacterType.Hero,
                        HERO_ATTACK_SKILLS, 
                        HERO_DEFENCE_SKILLS);
        villainInitialState = Character(randomInRange(VILLAIN_HEALTH_MIN, VILLAIN_HEALTH_MAX),
                        randomInRange(VILLAIN_STRENGTH_MIN, VILLAIN_STRENGTH_MAX),
                        randomInRange(VILLAIN_DEFENCE_MIN, VILLAIN_DEFENCE_MAX),
                        randomInRange(VILLAIN_SPEED_MIN, VILLAIN_SPEED_MAX), 
                        randomInRange(VILLAIN_LUCK_MIN, VILLAIN_LUCK_MAX),
                        CharacterType.Villain, 
                        VILLAIN_ATTACK_SKILLS,
                        VILLAIN_DEFENCE_SKILLS);
        currentTurnNumber = 0;

        // publishing the initial state


        decideAttacker();

        logAttackStatus();

        battleOutcome = BattleOutcome.InProgress;
    }

    function logAttackStatus() private {
        emit BattleStep(address(this), 
                        currentTurnNumber, 
                        CharacterType.Hero == currentAttack.attacker.characterType, 
                        currentAttack.attacker.health, 
                        currentAttack.defender.health, 
                        currentAttack.damage,
                        currentAttack.listAttackerUsedSkills,
                        currentAttack.listDefenderUsedSkills);
    }

    
    /**
    * It triggers and attack (can be either the hero or the villain). This function contains
    * all the actions performed in a turn.
    */
    function fight() onlyOwner public {  // triggered externally
        require(battleOutcome == BattleOutcome.InProgress, "The battle has ended");

        // using the attacker skills first
        for(uint8 i=0; i < currentAttack.attacker.attackSkills.length; i++) {
            useAttackSkill(currentAttack.attacker.attackSkills[i]);
        }

        // then we use the defender skills. This means that if the attacker strikes/harms 
        // the defender multiple times in one turn and the defender gets luky,
        // no damage is inflicted to the defender
        for(uint8 i=0; i < currentAttack.defender.defenceSkills.length; i++) {
            useDefenceSkill(currentAttack.defender.defenceSkills[i]);
        }

        // updating the defender's health
        Character storage defender = currentAttack.defender;
        if (defender.health >= currentAttack.damage) { //still alive
            defender.health = defender.health - currentAttack.damage;
        } else { 
            defender.health = 0; // game over
        }

        // storing the attack. It is useful for skill availability and testing/debugging
        previousAttacks.push(currentAttack);

        // publishing the new state after the fight
        logAttackStatus();

        decideBattleOutcome();
        
        // now changing roles
        Attack memory newAttack;
        newAttack.attacker = currentAttack.defender;
        newAttack.defender = currentAttack.attacker; 
        currentAttack = newAttack;
        currentTurnNumber++;  
    }

    function useAttackSkill(AttackSkillKey skillKey) private {
        Skill storage skill = mapAttackSkill[skillKey];
        // the probability is a simple condition while the available function performs more complex logic(e.g. availabilty based on historical usage) 
        if(randomUint() % 100 < skill.chanceOfBeingUsed && skill.available()) {
            // using the pointer to the function which performs the operation
            skill.action();
            // TODO: check if this data duplication is the most cost efficient (gas). 
            attackerUsedSkills[currentTurnNumber][skillKey] = true; // optimal search
            currentAttack.listAttackerUsedSkills.push(skillKey); // optimal storage for logging
        }
    }

    function useDefenceSkill(DefenceSkillKey skillKey) private {
        Skill storage skill = mapDefenceSkill[skillKey];
        if(randomUint() % 100 < skill.chanceOfBeingUsed && skill.available()) {
            // using the pointer to the function which performs the operation
            skill.action();
            defenderUsedSkills[currentTurnNumber][skillKey] = true; 
            currentAttack.listDefenderUsedSkills.push(skillKey); 
        }
    }

    
    function randomInRange(uint8 min, uint8 max) private returns (uint8) {
        return min + uint8(randomUint()) % (max - min);
    }

    function randomUint() internal virtual returns (uint) {
        // generating it by hashing the current block difficulty, the current time 
        randomNumberHelper++; 
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, currentTurnNumber, randomNumberHelper)));
    } 

    function basicStrikeFunction() private {
        
        currentAttack.damage += currentAttack.attacker.strength - currentAttack.defender.defence;
    }

    function basicDefenceFunction() private {
        if (randomUint() % 100 <= currentAttack.defender.luck) { // the defender got lucky this time
            currentAttack.damage = 0;
        }
    }
    
    function resilienceFunction() private { 
        // halving the damage
        currentAttack.damage /= 2;
    }

    function alwaysAvailable() private pure returns (bool) {
        return true;
    }

    function availableThirdStrike() private view returns (bool) {
        // third strike is available only if the second strike was used.
        if (attackerUsedSkills[currentTurnNumber][AttackSkillKey.SecondStrike]) {
            return true;
        }
        return false;

    }

    function availableResilience() private view returns (bool) {
        if (currentTurnNumber <= 1) { // this is the first time the defender defends herself
            return true;
        }
        // Last time the defender had the same role was 2 turns before. 
        // To be able to use resilience now, at that time he shouldn't have used resilience
        if (!defenderUsedSkills[currentTurnNumber - 2][DefenceSkillKey.Resilience]) {
            return true;
        }
        return false;

    }

    function changeDefenderHealth(Attack storage attack) private {
        if (attack.damage >= attack.defender.health){
            attack.defender.health = 0;
        } else {
            attack.defender.health -= attack.damage;
        }
    }

    function decideAttacker() private {
        if (heroInitialState.speed > villainInitialState.speed) {
            currentAttack.attacker = heroInitialState;
            currentAttack.defender = villainInitialState;
        } else if (heroInitialState.speed < villainInitialState.speed) {
            currentAttack.attacker = villainInitialState;
            currentAttack.defender = heroInitialState;
        } else if (heroInitialState.luck >= villainInitialState.luck) { // they have the same speed, relying on luck
            currentAttack.attacker = heroInitialState;
            currentAttack.defender = villainInitialState;
        } else {
            currentAttack.attacker = villainInitialState;
            currentAttack.defender = heroInitialState;
        }
    }

    function decideBattleOutcome() private { // game over?
        require(battleOutcome == BattleOutcome.InProgress, "The battle has ended");
        if (currentAttack.defender.health <= 0) {
             if(CharacterType.Hero == currentAttack.attacker.characterType){
                battleOutcome = BattleOutcome.HeroWon;
             } else {
                 battleOutcome = BattleOutcome.VillainWon;
             }
        } else if (currentTurnNumber >= BATTLE_MAX_NUM_TURNS - 1 ) {
            battleOutcome = BattleOutcome.Draw;
        }
        // if it reaches this point it means the battle is still in progress
    }

    function initSkillMappings() private {
        mapAttackSkill[AttackSkillKey.BasicStrike] = SKILL_BASIC_STRIKE;
        mapAttackSkill[AttackSkillKey.SecondStrike] = SKILL_SECOND_STRIKE;
        mapAttackSkill[AttackSkillKey.ThrirdStrike] = SKILL_THIRD_STRIKE;

        mapDefenceSkill[DefenceSkillKey.BasicDefence] = SKILL_BASIC_DEFENCE;
        mapDefenceSkill[DefenceSkillKey.Resilience] = SKILL_RESILIENCE;
    }
}

