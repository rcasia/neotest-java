
# Contributing to neotest-java

If you are here it means you are interested in contributing. Thank you for your help! :confetti_ball:

## :inbox_tray: Pull Requests
If you are considering to open a pull request for a little change, feel free do it straight forward. 
For larger changes, it is a good idea to open an issue first describing the feature idea or bug.

For the PRs to succeed and be merged you are expected to:
* have read this doc
* run the formatter before every commit
* add testcases for the feature or bugfix
* let me know if it is a work in progress or is already finished to be reviewed

### :electric_plug: Set up

#### Required dependencies for contributors
You will need to have installed:
* Java JDK 17 or 21
* This list of commands available in your terminal:
  * `stylua`
  * `make`
  * `git`

#### First build
The first step to setup your enviroment is to type:
```bash
make
```
This command will:
 1. clone neotest, plenary and nvim-treesitter
 2. install the java parser for nvim-treesitter
 3. build the java projects (it is expected to have some failing test)
 4. run neotest-java tests

#### Running tests

A. Using [neotest-plenary](https://github.com/nvim-neotest/neotest-plenary).


> Note: For the moment, you will need to specify the path to `.../neotest-java/tests/minimal_init.vim`
in the neotest-plenary configuration. See nvim-neotest/neotest-plenary#13

B. From terminal

* Run all tests (for lua changes):
  ```bash
  make test
  ```
* Run all tests (for lua and java changes): 
  ```bash
  make clean && make
  ```
* Run a test file:
  ```bash
  ./scripts/test [path-to-test-file]
  ```
