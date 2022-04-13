// SPDX-License-Identifier: MIT
pragma solidity =0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IPayment.sol";

interface IvRent is IERC721Receiver, IERC1155Receiver {
    event Leased(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint8 leasedAmount,
        uint256 leasingId,
        address indexed lenderAddress,
        uint8 maxRentDuration,
        bytes4 dailyRentPrice,
        bytes4 nftPrice,
        bool isERC721,
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
     * @dev sends your NFT to vera contract, which acts as an escrow
     * between the lender and the renter
     */
    function lease(
        address[] memory _nftAddress,
        uint256[] memory _tokenId,
        uint256[] memory _lendAmounts,
        uint8[] memory _maxRentDuration,
        bytes4[] memory _dailyRentPrice,
        bytes4[] memory _nftPrice,
        IPayment.PaymentToken[] memory _paymentToken
    ) external;

    /**
     * @dev renter sends rentDuration * dailyRentPrice
     * to cover for the potentially full cost of renting. They also
     * must send the collateral (nft price set by the lender in lend)
     */
    function rentNFT(
        address[] memory _nftAddress,
        uint256[] memory _tokenId,
        uint256[] memory _leasingIds,
        uint8[] memory _rentDurations
    ) external;

    /**
     * @dev renters call this to return the rented NFT before the
     * deadline. If they fail to do so, they will lose the posted
     * collateral
     */
    function endRent(
        address[] memory _nftAddress,
        uint256[] memory _tokenId,
        uint256[] memory _leasingIds
    ) external;

    /**
     * @dev claim collateral on rentals that are past their due date
     */
    function claimCollateral(
        address[] memory _nftAddresss,
        uint256[] memory _tokenIds,
        uint256[] memory _leasingIds
    ) external;

    /**
     * @dev stop leasing releases the NFT from escrow and sends it back
     * to the lender
     */
    function cancelLeasing(
        address[] memory _nftAddress,
        uint256[] memory _tokenId,
        uint256[] memory _leasingIds
    ) external;
}