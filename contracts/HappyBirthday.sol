// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SelfVerificationRoot} from "@selfxyz/contracts/contracts/abstract/SelfVerificationRoot.sol";
import {ISelfVerificationRoot} from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import {IVcAndDiscloseCircuitVerifier} from "@selfxyz/contracts/contracts/interfaces/IVcAndDiscloseCircuitVerifier.sol";
import {IIdentityVerificationHubV1} from "@selfxyz/contracts/contracts/interfaces/IIdentityVerificationHubV1.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Formatter} from "@selfxyz/contracts/contracts/libraries/Formatter.sol";
import {CircuitAttributeHandler} from "@selfxyz/contracts/contracts/libraries/CircuitAttributeHandler.sol";
import {CircuitConstants} from "@selfxyz/contracts/contracts/constants/CircuitConstants.sol";

contract HotelBooking is SelfVerificationRoot, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable paymentToken;
    
    // Price per bed
    uint256 public boysBedPrice;
    uint256 public girlsBedPrice;

    // Arrays to store bed numbers
    uint256[] public boysBeds;
    uint256[] public girlsBeds;

    // Mapping to track verified users and booked beds
    mapping(address => bool) public verifiedUsers;
    mapping(uint256 => bool) public bookedBeds;
    mapping(address => uint256) public userToBed;
    mapping(address => string) public userGender; // Store user's gender

    // Events
    event UserVerified(address indexed user);
    event BedBooked(address indexed user, uint256 bedNumber, bool isBoy);
    event BedPriceUpdated(uint256 newBoysPrice, uint256 newGirlsPrice);

    constructor(
        address _identityVerificationHub, 
        uint256 _scope, 
        uint256 _attestationId,
        address _token,
        uint256 _boysBedPrice,
        uint256 _girlsBedPrice,
        uint256[] memory _boysBeds,
        uint256[] memory _girlsBeds,
        bool _forbiddenCountriesEnabled,
        uint256[4] memory _forbiddenCountriesListPacked,
        bool[3] memory _ofacEnabled
    )
        SelfVerificationRoot(
            _identityVerificationHub, 
            _scope, 
            _attestationId, 
            false, // olderThanEnabled
            0,     // olderThan
            _forbiddenCountriesEnabled,
            _forbiddenCountriesListPacked,
            _ofacEnabled
        )
        Ownable(_msgSender())
    {
        paymentToken = IERC20(_token);
        boysBedPrice = _boysBedPrice;
        girlsBedPrice = _girlsBedPrice;
        boysBeds = _boysBeds;
        girlsBeds = _girlsBeds;
    }

    function verifyUser(
        IVcAndDiscloseCircuitVerifier.VcAndDiscloseProof memory proof
    ) external {
        // Verify the proof
        if (_scope != proof.pubSignals[CircuitConstants.VC_AND_DISCLOSE_SCOPE_INDEX]) {
            revert InvalidScope();
        }

        if (_attestationId != proof.pubSignals[CircuitConstants.VC_AND_DISCLOSE_ATTESTATION_ID_INDEX]) {
            revert InvalidAttestationId();
        }

        IIdentityVerificationHubV1.VcAndDiscloseVerificationResult memory result = _identityVerificationHub.verifyVcAndDisclose(
            IIdentityVerificationHubV1.VcAndDiscloseHubProof({
                olderThanEnabled: false,
                olderThan: _verificationConfig.olderThan,
                forbiddenCountriesEnabled: _verificationConfig.forbiddenCountriesEnabled,
                forbiddenCountriesListPacked: _verificationConfig.forbiddenCountriesListPacked,
                ofacEnabled: _verificationConfig.ofacEnabled,
                vcAndDiscloseProof: proof
            })
        );

        // Extract and store gender
        bytes memory charcodes = Formatter.fieldElementsToBytes(result.revealedDataPacked);
        string memory gender = CircuitAttributeHandler.getGender(charcodes);
        userGender[msg.sender] = gender;

        // Mark user as verified
        verifiedUsers[msg.sender] = true;
        emit UserVerified(msg.sender);
    }

    // Second step: Book a bed
    function bookBed(uint256 bedNumber) external {
        // Check if user is verified
        require(verifiedUsers[msg.sender], "User not verified");
        
        // Check if bed is already booked
        require(!bookedBeds[bedNumber], "Bed already booked");
        
        // Get stored gender
        string memory gender = userGender[msg.sender];
        
        // Check if bed number exists in the correct gender array
        bool isBoy = _isInArray(bedNumber, boysBeds);
        bool isGirl = _isInArray(bedNumber, girlsBeds);
        require(isBoy || isGirl, "Invalid bed number");
        if (isBoy) {
            require(keccak256(bytes(gender)) == keccak256(bytes("M")), "Bed reserved for boys only");
            require(paymentToken.transferFrom(msg.sender, address(this), boysBedPrice), "Payment failed");
        } else {
            require(keccak256(bytes(gender)) == keccak256(bytes("F")), "Bed reserved for girls only");
            require(paymentToken.transferFrom(msg.sender, address(this), girlsBedPrice), "Payment failed");
        }
        // Book the bed
        bookedBeds[bedNumber] = true;
        userToBed[msg.sender] = bedNumber;

        emit BedBooked(msg.sender, bedNumber, isBoy);
    }

    // Helper function to check if value exists in array
    function _isInArray(uint256 value, uint256[] memory array) internal pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }

    // View functions
    function getBoysBeds() public view returns (uint256[] memory) {
        return boysBeds;
    }

    function getGirlsBeds() public view returns (uint256[] memory) {
        return girlsBeds;
    }

    function isBedAvailable(uint256 bedNumber) public view returns (bool) {
        return !bookedBeds[bedNumber];
    }

    function getUserBed(address user) public view returns (uint256) {
        return userToBed[user];
    }

    function getBlockedCountries() public view returns (string[40] memory) {
        return Formatter.extractForbiddenCountriesFromPacked(_verificationConfig.forbiddenCountriesListPacked);
    }
    function isUserVerified(address user) public view returns (bool) {
        return verifiedUsers[user];
    }

    function getUserGender(address user) public view returns (string memory) {
        return userGender[user];
    }

    // Owner functions
    function updatePrices(uint256 _boysBedPrice, uint256 _girlsBedPrice) external onlyOwner {
        boysBedPrice = _boysBedPrice;
        girlsBedPrice = _girlsBedPrice;
        emit BedPriceUpdated(_boysBedPrice, _girlsBedPrice);
    }

    function withdrawFunds(address to, uint256 amount) external onlyOwner {
        paymentToken.safeTransfer(to, amount);
    }

    function addBeds(uint256[] memory newBoysBeds, uint256[] memory newGirlsBeds) external onlyOwner {
        for (uint256 i = 0; i < newBoysBeds.length; i++) {
            boysBeds.push(newBoysBeds[i]);
        }
        for (uint256 i = 0; i < newGirlsBeds.length; i++) {
            girlsBeds.push(newGirlsBeds[i]);
        }
    }

    function removeBeds(uint256[] memory boysBedsToRemove, uint256[] memory girlsBedsToRemove) external onlyOwner {
        for (uint256 i = 0; i < boysBedsToRemove.length; i++) {
            for (uint256 j = 0; j < boysBeds.length; j++) {
                if (boysBeds[j] == boysBedsToRemove[i]) {
                    boysBeds[j] = boysBeds[boysBeds.length - 1];
                    boysBeds.pop();
                    break;
                }
            }
        }
        for (uint256 i = 0; i < girlsBedsToRemove.length; i++) {
            for (uint256 j = 0; j < girlsBeds.length; j++) {
                if (girlsBeds[j] == girlsBedsToRemove[i]) {
                    girlsBeds[j] = girlsBeds[girlsBeds.length - 1];
                    girlsBeds.pop();
                    break;
                }
            }
        }
    }
}