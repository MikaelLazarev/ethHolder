//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


import "hardhat/console.sol";

// CONSTANTS
address constant CHAINLINK_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
int256 constant PERCENTAGE_FACTOR = 100;


enum Mood {
  TO_THE_MOON,
  BULLISH,
  STABLE,
  PANIC,
  APPLYING_TO_MC_DONALDS
}

contract ETHodlerNft is ERC721, Ownable {
  AggregatorV3Interface public immutable priceFeed;

  mapping(Mood => string) public pfps;
  mapping(uint256 => mapping(Mood => string)) public customPfps;
  mapping(uint256 => bool) hasCustomPfp;

  constructor(string[] memory defaultPictures)
    ERC721("ETH Hodler Nft token", "HODL")
  {
    require(defaultPictures.length == 5, "Incorrect pictures array length");
    priceFeed = AggregatorV3Interface(CHAINLINK_ORACLE);
    for (uint256 i = 0; i < 5; i++) {
      pfps[Mood(i)] = defaultPictures[i];
    }
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
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    Mood mood = getMarketMood();
    return hasCustomPfp[tokenId] ? customPfps[tokenId][mood] : pfps[mood];
  }

  function customize(
    uint256 tokenId,
    string memory toTheMoon,
    string memory bullish,
    string memory stable,
    string memory panic,
    string memory applyingToMacDonalds
  ) external {
    require(
      msg.sender == ownerOf(tokenId),
      "Only owners could customize tokens"
    );
    require(!hasCustomPfp[tokenId], "Token is already customized");
    customPfps[tokenId][Mood.TO_THE_MOON] = toTheMoon;
    customPfps[tokenId][Mood.BULLISH] = bullish;
    customPfps[tokenId][Mood.STABLE] = stable;
    customPfps[tokenId][Mood.PANIC] = panic;
    customPfps[tokenId][Mood.APPLYING_TO_MC_DONALDS] = applyingToMacDonalds;
  }

  function mint(address to, uint256 tokenId) external onlyOwner {
    _mint(to, tokenId);
  }

  /// @dev Returns market mood for the last 24h
  /// @return mood (enum)
  function getMarketMood() public view returns (Mood) {
    int256 priceChange = getPriceChange();
    if (priceChange > 10) {
      return Mood.TO_THE_MOON;
    }

    if (priceChange > 5) {
      return Mood.BULLISH;
    }

    if (priceChange < -10) {
      return Mood.APPLYING_TO_MC_DONALDS;
    }

    if (priceChange < -5) {
      return Mood.PANIC;
    }

    return Mood.STABLE;
  }

  /// @dev Calculates ETH / USD price deviations for the last 24h
  /// @return signed change in percentage format (x100)
  function getPriceChange() public view returns (int256) {
    (uint80 roundID, int256 priceNow, , uint256 timeStampNow, ) = priceFeed
      .latestRoundData();

    roundID -= 24;
    while (true) {
      (, int256 price, , uint256 timeStamp, ) = priceFeed.getRoundData(roundID);

      if (timeStamp + 1 days < timeStampNow) {
        return (PERCENTAGE_FACTOR * (priceNow - price)) / priceNow;
      }

      roundID--;
    }
  }
}
