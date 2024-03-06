![ERC404P](https://raw.githubusercontent.com/erc404p/contracts/main/cover.jpg "ERC404P")

# ERC 404P

## I. Purpose of Introducing ERC404P
ERC404P was born to explore more possibilities of ERC404, especially in GameFi.
Continuing the concept of merging tokens and NFT, ERC404P proposes optimization schemes for reducing gas fees, improving NFT applications, and introducing practical extensions.
This project will be open source, and we welcome more NFT and Gamefi teams to join us in enhancing ERC404P together.

## II. Key Features
1. Conversion Formula: 1 NFT (ERC721) = 10,000 Tokens (ERC20).
2. Self-service Conversion Method:
Transferring a quantity of 10,000n tokens to the token contract will yield n NFTs, and any remaining tokens less than 10,000 will be automatically refunded.
Transferring NFTs to the token contract will yield 98% of the tokens, with the remaining 2% automatically sent to a black hole address for burning.
The purpose of the destruction mechanism are: to increase the value of scarce attribute NFTs and to facilitate the economic model of blind boxes and collectibles gameplay.
3. Significantly reduced gas fees when transferring tokens.
4. NFT IDs are stored in a queue and reused, ensuring that the ID number does not continually increase during minting, thereby preserving the scarcity of attributes.
5. Partial implementation of the IERC721Enumerable.sol interface provides convenience for DApp development.
6. Simple Fair Minting is achieved through token transfers to the token contract.

# MIT License

Copyright (c) 2024 erc404p

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
