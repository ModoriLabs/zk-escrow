// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseTest.sol";
import { Escrow } from "../src/Escrow.sol";
import { IEscrow } from "../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseEscrowTest is BaseTest {
    TossBankReclaimVerifierV2 public tossBankReclaimVerifierV2;
    Escrow public escrow;

    address public constant VERIFIER_ADDRESS_V2 = 0x2042c7E7A36CAB186189946ad751EAAe6769E661;
    string public constant CHAIN_NAME = "anvil";
    uint256 public constant INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes
    uint256 public constant KRW_CONVERSION_RATE = 1380e18;

    address public escrowOwner;
    address public usdtOwner;

    function setUp() public virtual override {
        super.setUp();

        // Set owner references first
        usdtOwner = usdt.owner();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 1_000_000e6); // 1M USDT
        usdt.mint(bob, 500_000e6); // 500K USDT
        usdt.mint(charlie, 300_000e6); // 300K USDT
        vm.stopPrank();

        // Deploy Escrow contract with MockUSDT
        escrow = new Escrow(owner, INTENT_EXPIRATION_PERIOD, CHAIN_NAME);

        // Create TossBankReclaimVerifierV2 for escrow (V2 interface)
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;

        bytes32[] memory verifierCurrencies = new bytes32[](1);
        verifierCurrencies[0] = keccak256("KRW");

        tossBankReclaimVerifierV2 = new TossBankReclaimVerifierV2(
            owner,
            address(escrow),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            verifierCurrencies,
            providerHashes
        );

        vm.prank(owner);
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifierV2));

        vm.prank(owner);
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifierV2));

        escrowOwner = escrow.owner();
    }

    /**
     * @notice Creates a standard deposit with configurable parameters
     * @param depositor The address that will create the deposit (defaults to alice)
     * @param depositAmount The amount to deposit (defaults to 10,000 USDT)
     * @param minIntent Minimum intent amount (defaults to 100 USDT)
     * @param maxIntent Maximum intent amount (defaults to 2000 USDT)
     * @return depositId The ID of the created deposit
     */
    function _createDeposit(
        address depositor,
        uint256 depositAmount,
        uint256 minIntent,
        uint256 maxIntent
    )
        internal
        returns (uint256 depositId)
    {
        IEscrow.Range memory intentRange = IEscrow.Range({ min: minIntent, max: maxIntent });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] =
            IEscrow.DepositVerifierData({ payeeDetails: "test-payee-details", data: abi.encode("test-data") });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: KRW_CONVERSION_RATE });

        vm.startPrank(depositor);
        usdt.approve(address(escrow), depositAmount);
        depositId =
            escrow.createDeposit(IERC20(address(usdt)), depositAmount, intentRange, verifiers, verifierData, currencies);
        vm.stopPrank();
    }

    /**
     * @notice Creates a deposit with default parameters (alice, 10K USDT, 100-2000 USDT intent range)
     */
    function _createDeposit() internal returns (uint256 depositId) {
        return _createDeposit(alice, 10_000e6, 100e6, 2000e6);
    }

    function _loadProofV2() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tests/fixtures/escrow-proof-anvil.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        // proof = abi.decode(data, (IReclaimVerifier.ReclaimProof));

        // Parse individual fields instead of decoding entire struct
        proof.claimInfo.provider = vm.parseJsonString(json, ".claimInfo.provider");
        proof.claimInfo.parameters = vm.parseJsonString(json, ".claimInfo.parameters");
        proof.claimInfo.context = vm.parseJsonString(json, ".claimInfo.context");

        proof.signedClaim.claim.identifier = vm.parseJsonBytes32(json, ".signedClaim.claim.identifier");
        proof.signedClaim.claim.owner = vm.parseJsonAddress(json, ".signedClaim.claim.owner");
        proof.signedClaim.claim.timestampS = uint32(vm.parseJsonUint(json, ".signedClaim.claim.timestampS"));
        proof.signedClaim.claim.epoch = uint32(vm.parseJsonUint(json, ".signedClaim.claim.epoch"));

        // Handle signatures array
        // 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000636c417755e3ae25c6c166d181c0607f4c572a3000000000000000000000000244897572368eadf65bfbc5aec98d8e5443a9072
        // 1 slot is 32 bytes, 64 hex chars
        // slot0: 0x20
        // slot1: 0x2
        // slot2: address1
        // slot3: address2
        string memory sigHex = vm.parseJsonString(json, ".signedClaim.signatures[0]");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = vm.parseBytes(sigHex);
        console.logBytes(signatures[0]);
        proof.signedClaim.signatures = signatures;

        proof.isAppclipProof = vm.parseJsonBool(json, ".isAppclipProof");
    }
}
