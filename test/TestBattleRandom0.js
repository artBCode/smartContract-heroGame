const Battle = artifacts.require("./BattleRandom0.sol");

// testing the battle in which the random number generator always returns 0
contract("BattleRandom0", accounts => {
    it("... check proper initialization.", async () => {
        const battleInstance = await Battle.new();

        const battleOutcome = await battleInstance.battleOutcome();
        assert.equal(battleOutcome, 0, "The battle should be in progress");

        const currentTurn = await battleInstance.currentTurnNumber();
        assert.equal(currentTurn, 0, "This should be turn 0");

        const hero = await battleInstance.heroInitialState();
        assert.isTrue(hero.health==70, "Bad initial hero health.");
        assert.isTrue(hero.strength==70, "Bad initial hero strength");
        assert.isTrue(hero.defence==45, "Bad initial hero defence");
        assert.isTrue(hero.speed ==40, "Bad initial hero speed");
        assert.isTrue(hero.luck ==10, "Bad initial hero luck");
        assert.equal(hero.characterType, 0, "not a hero");


        const villain = await battleInstance.villainInitialState();
        assert.isTrue(villain.health ==60, "Bad initial villain health.");
        assert.isTrue(villain.strength ==60, "Bad initial villain strength");
        assert.isTrue(villain.defence ==40, "Bad initial villain defence");
        assert.isTrue(villain.speed ==40, "Bad initial villain speed");
        assert.isTrue(villain.luck ==25, "Bad initial villain luck");
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

    it("... check no health update on both sides", async () => {
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

    it("... check game ends at turn 20, then it throws exception", async () => {
        const battleInstance = await Battle.new();
        battleOutcome = await battleInstance.battleOutcome();
        for(i=0; i<20 && battleOutcome==0; i++) {
            
            await battleInstance.fight();
            battleOutcome = await battleInstance.battleOutcome();
            // console.log("turn "+i+" outcome "+battleOutcome);
        }
        console.log("Battle ended in " + i + " turns\n");
        assert.equal(i, 20, "expected to end the battle exactly after 20 fights");
        assert.equal(battleOutcome, 3, "expected a draw")

        // now it should throw an exception
        try {
            await battleInstance.fight();
            assert.fail("The transaction should have thrown an error");
        }
        catch (err) {
            assert.include(err.message, "The battle has ended", "The error message should contain 'The battle has ended'");
        }
        
    });

    it("... check that all the skills are used in the battle. Resilience every other turn", async () => {
        const battleInstance = await Battle.new();
        battleOutcome = await battleInstance.battleOutcome();
        resilienceUsed = false;
        for(i=0; i<20 && battleOutcome==0; i++) {
            fightResult = await battleInstance.fight();
            const hasHeroAttacked = fightResult.logs[0].args.heroAttacked;
            if(hasHeroAttacked){
                assertEqualList(fightResult.logs[0].args.listAttackerUsedSkills, [0, 1, 2], "incorrect attacker skills"); // super hero :)
                assertEqualList(fightResult.logs[0].args.listDefenderUsedSkills, [0], "incorrect defender skills");
            } else {
                assertEqualList(fightResult.logs[0].args.listAttackerUsedSkills, [0], "incorrect attacker skills");
                if(!resilienceUsed) { // resilience skill is used every other turn
                    assertEqualList(fightResult.logs[0].args.listDefenderUsedSkills, [0, 1], "incorrect defender skills"); // super hero 
                    resilienceUsed = true;
                } else {
                    assertEqualList(fightResult.logs[0].args.listDefenderUsedSkills, [0], "incorrect defender skills"); // normal
                    resilienceUsed = false;
                }
                
            }

            battleOutcome = await battleInstance.battleOutcome();
        }
        
    });

    function assertEqualList(list1, list2, erorMsg){
        assert.equal(list1.length, list2.length, erorMsg + " Different length");
        for(i=0;i<list1.length;i++){
             assert.equal(list1[i], list2[i], erorMsg + " Different elem "+ i);
        }

    }

    function checkCorrectDamage(fightResult, heroHealthBeforeFight, villainHealthBeforeFight) {
        const hasHeroAttacked = fightResult.logs[0].args.heroAttacked;
        const damage = parseInt(fightResult.logs[0].args.damage);
        const defenderHealthAfterFight = parseInt(fightResult.logs[0].args.defenderHealth);
        const attackerHealthAfterFight = parseInt(fightResult.logs[0].args.attackerHealth);
        if(hasHeroAttacked) {
            // always 0 bacause the random number is always 0
            assert.isTrue(damage == 0, "the villain got hit too hard"); 
            // the hero health stays the same
            assert.equal(attackerHealthAfterFight, heroHealthBeforeFight, "Incorrect hero health. It should have been unaffected.");
            // villain's health decreases or stays the same if he gets lucky 
            assert.equal(defenderHealthAfterFight, villainHealthBeforeFight, "Incorrect villain health after attack");
        } else {
            // always 0 bacause the random number is always 0
            assert.isTrue(damage == 0, "the hero got hit too hard"); 
            // hero health decrease
            assert.equal(defenderHealthAfterFight, heroHealthBeforeFight, "Incorrect hero health after attack");
            // the villain health remains unchanged
            assert.equal(attackerHealthAfterFight, villainHealthBeforeFight, "Incorrect villain health. It should have been unaffected.");
        }
    }
});
