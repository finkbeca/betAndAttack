
## Overview

Main Contracts can be found in /src/
    - BetAndAttack.sol is the main contract
    - BetAndAttackFixed.sol is an adaption for BetAndAttack for testing purposes on a local test net.
    - provableAPI is an external contract managed by Provable.xyz

Testing can be found in /test/
    - BetAndAttackFixed.t.sol is the test version for BetAndAttack

Contracts can be built with ```forge compile```


## Running Tests
(General Foundry Documentation: https://book.getfoundry.sh/)

### Installing Foundry (macOS)

```curl -L https://foundry.paradigm.xyz | bash```

then run ```foundryup```

finally run
``` forge install``` in the root directory of the project

### Running Tests:
To compile contracts and run all tests use 
``` forge test```

Note: you may use multiples of the "v" command to see additional information / traces of test, (maximum visivility is ```forge test vvvvv```)