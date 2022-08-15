const Battle = artifacts.require("./Battle.sol");

// testing the real contract
contract("Battle", accounts => {
    it("... check proper initialization.", async () => {
        const battleInstance = await Battle.new();

        const battleOutcome = await battleInstance.battleOutcome();
        assert.equal(battleOutcome, 0, "The battle should be in progress");

        const currentTurn = await battleInstance.currentTurnNumber();
        assert.equal(currentTurn, 0, "This should be turn 0");

        const hero = await battleInstance.heroInitialState();
        assert.isTrue(hero.health >=70 && hero.health <=100, "Bad initial hero health.");
        assert.isTrue(hero.strength >=70 && hero.strength <=80, "Bad initial hero strength");
        assert.isTrue(hero.defence >=45 && hero.defence <=55, "Bad initial hero defence");
        assert.isTrue(hero.speed >=40 && hero.speed <=50, "Bad initial hero speed");
        assert.isTrue(hero.luck >=10 && hero.luck <=30, "Bad initial hero luck");
        assert.equal(hero.characterType, 0, "not a hero");


        const villain = await battleInstance.villainInitialState();
        assert.isTrue(villain.health >=60 && villain.health <=90, "Bad initial villain health.");
        assert.isTrue(villain.strength >=60 && villain.strength <=90, "Bad initial villain strength");
        assert.isTrue(villain.defence >=40 && villain.defence <=60, "Bad initial villain defence");
        assert.isTrue(villain.speed >=40 && villain.speed <=60, "Bad initial villain speed");
        assert.isTrue(villain.luck >=25 && villain.luck <=40, "Bad initial villain luck");
        assert.equal(villain.characterType, 1, "not a villain");
    });


    it("... check hero and villain attack alternatively ", async () => {
        const battleInstance = await Battle.new();
        
        const fight1Result = await battleInstance.fight();
        const hasHeroAttacked1 = fight1Result.logs[0].args.heroAttacked;

        const fight2Result = await battleInstance.fight();
        const hasHeroAttacked2 = fight2Result.logs[0].args.heroAttacked;
        
        assert.isTrue(hasHeroAttacked1!=hasHeroAttacked2, "Hero and villain should have exchanged their roles");
    });

    it("... check health update on both sides", async () => {
        const battleInstance = await Battle.new();

        const heroInitialState = await battleInstance.heroInitialState();
        const villainInitialState = await battleInstance.villainInitialState();
        
        const fight1Result = await battleInstance.fight(); // first fight
        assert.equal(parseInt(fight1Result.logs[0].args.turnNumber), 0, "expecting turn 0"); // ensure this is a fresh contract
        checkCorrectDamage(fight1Result, parseInt(heroInitialState.health), parseInt(villainInitialState.health));

        const fight2Result = await battleInstance.fight(); // second fight. the response to the first one
        if(fight1Result.logs[0].args.heroAttacked){
            checkCorrectDamage(fight2Result, fight1Result.logs[0].args.attackerHealth, fight1Result.logs[0].args.defenderHealth);
        } else {
            checkCorrectDamage(fight2Result, fight1Result.logs[0].args.defenderHealth, fight1Result.logs[0].args.attackerHealth);
        } 
        
    });

    it("... check game ends and then throws exception", async () => {
        const battleInstance = await Battle.new();
        battleOutcome = await battleInstance.battleOutcome();
        for(i=0; i<20 && battleOutcome==0; i++) {
            await battleInstance.fight();
            battleOutcome = await battleInstance.battleOutcome();
        }
        console.log("Battle ended in " + i + " turns\n");
        assert.isTrue(battleOutcome != 0, "after 21 tunrns the game has not ended");

        // now it should throw an exception
        try {
            await battleInstance.fight();
            assert.fail("The transaction should have thrown an error");
        }
        catch (err) {
            assert.include(err.message, "The battle has ended", "The error message should contain 'The battle has ended'");
        }
        
    });

    function checkCorrectDamage(fightResult, heroHealthBeforeFight, villainHealthBeforeFight) {
        const hasHeroAttacked = fightResult.logs[0].args.heroAttacked;
        const damage = parseInt(fightResult.logs[0].args.damage);
        const defenderHealthAfterFight = parseInt(fightResult.logs[0].args.defenderHealth);
        const attackerHealthAfterFight = parseInt(fightResult.logs[0].args.attackerHealth);
        if(hasHeroAttacked) {
            // in the worst case the villain receives 3 strikes x (80-40) damage/strike = 120 
            assert.isTrue(damage <=120, "the villain got hit too hard"); 
            // the hero health stays the same
            assert.equal(attackerHealthAfterFight, heroHealthBeforeFight, "Incorrect hero health. It should have been unaffected.");
            // villain's health decreases or stays the same if he gets lucky 
            assert.equal(defenderHealthAfterFight, villainHealthBeforeFight - damage, "Incorrect villain health after attack");
        } else {
            // in the worst case the hero receives 90-45=45 damage
            assert.isTrue(damage <=45, "the hero got hit too hard"); 
            // hero health decrease
            assert.equal(defenderHealthAfterFight, heroHealthBeforeFight - damage, "Incorrect hero health after attack");
            // the villain health remains unchanged
            assert.equal(attackerHealthAfterFight, villainHealthBeforeFight, "Incorrect villain health. It should have been unaffected.");
        }
    }
});
