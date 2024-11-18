# Include environment variables
-include .env

# Define phony targets
.PHONY: all build test install deploy-sepolia

# Build the project
build: 
	forge build

# Run tests
test: 
	forge test

# Install dependencies
install: 
	forge install cyfrin/foundry-devops --no-commit \
		&& forge install smartcontractkit/chainlink-brownie-contracts --no-commit \
		&& forge install foundry-rs/forge-std --no-commit \
		&& forge install transmissions11/solmate --no-commit

# Deploy to Sepolia network
deploy-sepolia: 
	@forge script scripts/DeployRaffle.s.sol:DeployRaffle \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account deployer \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
