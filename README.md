
# ETHERBOTS Bug Bounty

**ETHERBOTS** is a decentralised Robot Wars game on the Ethereum blockchain. It is currently live on the Rinkeby testnet at https://etherbots.io/. This wiki will step you through a high level overview of the code, and set out a criteria for submitting bugs. The github code will be updated frequently as we respond to bugs, so make sure to pull the latest versions. We highly recommend cloning/forking a version of this repository so you have access to linter & build functionalities for your convenience.



### INTRODUCTION TO ETHERBOTS

- ETHERBOTS is a game where you can fight, collect and trade Robots. 
- Each part is a non-fungible ERC721 token, fully owned by users.
- Parts can be gained in several ways.
- 1. Battling provides a number of shards based on your performance in battle and a random modifier. These shards can be redeemed for parts.
- 2. Battling can randomly give you a part as an immediate reward, if you are very lucky.
- 3. Parts can be bought and sold on the user run marketplace.
- 4. Parts can be "scrapped" to redeem 70% of the shard value of a part crate.

Some users already have parts, which they bought during the presale. These users will migrate their parts into full ERC721 tokens, a process coded in EtherbotsMigrations.sol.

### BUG BOUNTY

This bounty will run within the Rinkeby network from <b> 11.59 PM PST February 23 - 11:59pm PST March 2, 2018</b>.

The initial fund allocated to this Bounty is **10 Ether**. However we will update the wiki if this is exhausted, and allocate more funds as required.


# Our main area of concerns are
-   Anything which breaks the game or makes it non-functional (getting robots "stuck" in battles, etc.)
- Stealing other people's robot parts
- Gaining an unfair advantage over other people (accessing defender's secret commits without social engineering)
- Stealing ETH from any of the contracts or users
- Illegitimately using an onlyOwner function or changing state in a way regular users shouldn't be allowed to
- Errors in programming/game logic which would impact gameplay
- Gas efficiency, particularly in the battle contract (_executeMoves function)


### Rules
1. Issues will only be considered as valid if they have not been submitted by another user, or are not known to the Etherbots team. 
2. Please stay legal. No DDOSing, no social engineering, etc. The live game on the Etherbots website is a useful way to interact with the contract as users would, but it is not part of the bounty itself. 
3. We *are* interested in economic logic or game logic errors to do with the expected value of battling, reward crates, etc. While difficult to quantify, if you make a reasonable suggestion based on a serious error of ours which we implement, we will reward it.
4. Please submit all reports via GitHub issues on **this** repository in order to be eligible for rewards.
5. Final note: all rewards is at the sole discretion of the ETHERBOTS team. We will conduct this bounty in very good faith, as the security of our user's parts and game experience is paramount to us. We ask you do the same, and don't disrupt user's testnet experience or act in a harmful manner. <3 
## REWARD CRITERION

Rewards will be determined according a risk matrix of impact severity and likelihood, defined by 
  [OWASP](https://www.owasp.org/index.php/OWASP_Risk_Rating_Methodology).
![enter image description here](https://masterykatas.files.wordpress.com/2010/05/riskrating.jpg)

*1 point = 1 USD worth of ETH at time of payment.*
- **Critical**: up to 1000 points 
*Examples*: Steal someones part trivially. Steal ETH off a user or the contract. Access onlyOwner functions. Ruin a significant portion of game experience. 
- **High**: up to 500 points
*Examples*: Access things for free, i.e. battling without battle fees. Control any functions' randomness in an exploitable way.
- **Medium**: up to 250 points
*Examples:* Disrupt other user's actions, such as stopping them from being able to bid on an auction, stopping them from battling or revealing moves, etc. 
- **Low**: up to 100 points
- *Examples*: Scaling issues -- anything that might break with large amounts of users. Improvements in gas efficiency (we will consider proportionate to gas saved -- if highly significant and a specific fix is recommended, we will award higher points than this cap. Keep in mind the functionality needs to remain the same.)  Break the strategic integrity of the game (i.e. find a way to collude beneficially). 

Please be **clear** in your description of the bug. Recreate the exact steps needed to make the bug happen with screenshots, code, a video or descriptions.

**For higher points, suggest how we can fix the bug.**

**Rules for Etherbots**
- We will respond as  promptly as possible to all bug submissions.
- We'll let you know if your bug qualified for a bounty within a business week.
- No Etherbots team members, developers or contractors are eligible for bounties.


<b>Disclaimer:</b>
This bug bounty is an attempt by the ETHERBOTS team to ensure the highest level of security and seamlessness in the final game experience. The code published here is purely for testing purposes and is not open source or available for private or commercial use without our express permission.

Copyright (c) 2018 Fuel Bros Pty, Ltd. All rights reserved.
