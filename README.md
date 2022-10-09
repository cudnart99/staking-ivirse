# staking-ivirse

## How to use (deploy in remix)

- Step 1 : User A deploy token A in [Token.sol](./contracts/Token.sol)
- Step 2 : User B deploy token B in [Token.sol](./contracts/Token.sol)
- Step 3 : User B deploy contract StakingBonus in [Staking_new.sol](./contracts/Staking_new.sol)
- Step 4 : User B mint coin for contract StakingBonus
- Step 5 : User A mint coin for user who want to stake (Customer)
- Step 6 : Customer approve coin to contract StakingBonus
- Step 7 : Customer stake coin by providing amount stake and duration stake
- Step 8 : After the duration end , customer can use withdrawFullTime to get bonus (tokenB) and token A back
<p>Customer can also withdraw before the duration end and run some view function to get detail of their stake</p>

Those option are described in comment section in [Staking_new.sol](./contracts/Staking_new.sol)






