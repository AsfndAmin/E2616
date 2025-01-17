// SPDX-License-Identifier: MIT
pragma solidity =0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./IPayment.sol";

interface IvRent2615 is IERC721Receiver {
    event Leased(
        uint256 indexed tokenId,
        uint256 leasingId,
        address indexed leaserAddress,
        uint8 maxRentDuration,
        bytes4 dailyRentPrice,
        IPayment.PaymentToken paymentToken
    );

    event Rented(
        uint256 leasingId,
        address indexed renterAddress,
        uint8 rentDuration,
        uint32 rentedAt
    );

    event Returned(uint256 indexed leasingId, uint32 returnedAt);

    event CollateralClaimed(uint256 indexed leasingId, uint32 claimedAt);

    event LeasingStopped(uint256 indexed leasingId, uint32 stoppedAt);

    /**
     * @dev sends your NFT to ReNFT contract, which acts as an escrow
     * between the lender and the renter
     */
    function lease(
        uint256[] memory _tokenId,
        uint8[] memory _maxRentDuration,
        bytes4[] memory _dailyRentPrice,
        IPayment.PaymentToken[] memory _paymentToken
    ) external;

    /**
     * @dev renter sends rentDuration * dailyRentPrice
     * to cover for the potentially full cost of renting. They also
     * must send the collateral (nft price set by the lender in lend)
     */
    function rentNFT(
        uint256[] memory _tokenId,
        uint256[] memory _leasingIds,
        uint8[] memory _rentDurations
    ) external;

    /**
     * @dev renters call this to return the rented NFT before the
     * deadline. If they fail to do so, they will lose the posted
     * collateral
     */
    function endRent(uint256[] memory _tokenId, uint256[] memory _leasingIds)
        external;

    /**
     * @dev stop lending releases the NFT from escrow and sends it back
     * to the lender
     */
    function cancelLeasing(
        uint256[] memory _tokenId,
        uint256[] memory _leasingIds
    ) external;
}
