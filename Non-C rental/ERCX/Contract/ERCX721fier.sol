// SPDX-License-Identifier: unlicense
pragma solidity ^0.8.0;

import "./ERCX.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title ERC721 Non-Fungible Token Standard compatible layer
 * Each items here represents owner of the item set.
 * By implementing this contract set, ERCX can pretend to be an ERC721 contrtact set.
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract ERCX721fier is Context, ERC165, IERC721, ERCX, IERC721Metadata {
    using Address for address;
    using Strings for uint256;
    // bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    // bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        // register the supported interfaces to conform to ERC721 via ERC165
        // _registerInterface(_INTERFACE_ID_ERC721);
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165, ERC165Storage)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId, 1),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return balanceOfOwner(owner);
    }

    function ownerOf(uint256 itemId)
        public
        view
        override(ERCX, IERC721)
        returns (address)
    {
        return super.ownerOf(itemId);
    }

    function approve(address to, uint256 itemId) public virtual override {
        approveForOwner(to, itemId);
        address owner = ownerOf(itemId);
        emit Approval(owner, to, itemId);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override(ERCX, IERC721)
    {
        super.setApprovalForAll(operator, approved);
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(IERC721, ERCX)
        returns (bool)
    {
        return super.isApprovedForAll(owner, operator);
    }

    function getApproved(uint256 itemId)
        public
        view
        override
        returns (address)
    {
        return getApprovedForOwner(itemId);
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        super._mint(to, tokenId);

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 itemId
    ) public virtual override {
        require(_isEligibleForTransfer(_msgSender(), itemId, 2));

        if (getCurrentTenantRight(itemId) == address(0)) {
            _transfer(from, to, itemId, 1);
            _transfer(from, to, itemId, 2);
        } else {
            _transfer(from, to, itemId, 2);
        }
        emit Transfer(from, to, itemId);

        _afterTokenTransfer(from, to, itemId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 itemId
    ) public virtual override {
        safeTransferFrom(from, to, itemId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 itemId,
        bytes memory data
    ) public virtual override {
        transferFrom(from, to, itemId);
        require(
            _checkOnERC721Received(from, to, itemId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
