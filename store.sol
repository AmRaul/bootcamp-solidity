// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Store is Ownable {

    uint256 totalRevenue;

    /// @notice buyer => product_id => quantity
    mapping(address => mapping(uint256 => uint256)) private userPurchase;
    /// @notice product_id => quantity
    mapping(uint256 => uint256) private productPurchase;
    /// @notice buyer => purchase 
    mapping(address => Purchase[]) private userPurchases;
    ///@notice discountCode => discountAmount
    mapping(string => uint256) private discountCodes; 

    struct Product {
        string name;
        uint256 id;
        uint256 stock;
        uint256 price;
    }

    struct Purchase {
        uint256 productId;
        uint256 quantity;
        uint256 paidPrice;
        uint256 timeStamp;
    }

    Product[] private products;

    event PurchaseMade(address buyer, uint256 id, uint256 quantity, uint256 paidPrice);
    event ReturnMade(address buyer, uint256 id, uint256 quantity, uint256 returnPrice);

    error IdAlreadyExist();
    error IdDoesNotExist();
    error OutOfStock();
    error NotEnoughtFunds();
    error QuantityCantBeZero();
    error ThereIsNoProducts();
    error userHasNoPurchases();
    error cantRefundAfter24h();
    error dontHaveMoneyForReturn();
    error CantBeMoreThan90Less0();
    error DiscountCodeExist();

    construct() Ownable(msg.sender){}

    function buy(uint256 _id, uint256 _quantity, string calldata discountCode) external payable  {
        require(_quantity > 0, QuantityCantBeZero());
        require(getStock(_id) >= _quantity, OutOfStock());
        
        uint256 discount = discountCodes[discountCode];
        uint256 totalPrice = getPrice(_id)*_quantity;

        if (discount > 0) {
            totalPrice = (totalPrice * (100 - discount) /100);
        }
        require(msg.value >= totalPrice, NotEnoughtFunds());
        _buyProccess(msg.sender, _id, _quantity, totalPrice);

        if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function batchBuy(uint256[] calldata _ids, uint256[] calldata _quantities, string calldata discountCode) external payable {
        require(_ids.length == _quantities.length, "Array lenght not correct");

        uint256 totalPrice = 0;

        for(uint256 i =0; i<_ids.length; i++) {
            uint256 quantity = _quantities[i];
            uint256 id = _ids[i];

            require(quantity > 0, QuantityCantBeZero());
            require(getStock(id) >= quantity, OutOfStock());

            totalPrice += getPrice(id)*quantity;
        }

        uint256 discount = discountCodes[discountCode];

        if (discount > 0) {
            totalPrice = (totalPrice * (100 - discount) /100);
        }
        require(msg.value >= totalPrice, NotEnoughtFunds());

        for(uint256 i =0; i<_ids.length; i++) {
            _buyProccess(msg.sender, _ids[i], _quantities[i], totalPrice);
        }

        if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function _buyProccess(address buyer, uint256 _id, uint256 _quantity, uint256 _paidPrice) internal {
        Product storage product = findProduct(_id);
        product.stock -= _quantity;

        userPurchase[buyer][_id] += _quantity; 
        productPurchase[_id] += _quantity;

        userPurchases[buyer].push(Purchase(_id,_quantity,_paidPrice, block.timestamp));
        totalRevenue += _paidPrice;
        emit PurchaseMade (buyer, _id, _quantity,_paidPrice);

    }

    function refund() public {
        require(userPurchases[msg.sender].length > 0, userHasNoPurchases());
 
        Purchase storage lastPurchase = userPurchases[msg.sender][userPurchases[msg.sender].length -1];
        Product storage product = findProduct(lastPurchase.productId);
         
        require(block.timestamp - lastPurchase.timeStamp <= 1 days, cantRefundAfter24h());
        require(address(this).balance >= lastPurchase.paidPrice, dontHaveMoneyForReturn());

        userPurchase[msg.sender][lastPurchase.productId] -= lastPurchase.quantity;
        productPurchase[lastPurchase.productId] -= lastPurchase.quantity;
        totalRevenue -= lastPurchase.paidPrice; 
        product.stock += lastPurchase.quantity;

        payable(msg.sender).transfer(lastPurchase.paidPrice);

        emit ReturnMade(msg.sender, lastPurchase.productId, lastPurchase.quantity, lastPurchase.paidPrice);

        userPurchases[msg.sender].pop();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw"); 
        payable(owner()).transfer(balance);
    }

    function addDiscountCode(string calldata _code, uint256 _codeAmount) external onlyOwner {
        require(_codeAmount <= 90 && _codeAmount > 0,CantBeMoreThan90Less0());
        require(discountCodes[_code] == 0, DiscountCodeExist());

        discountCodes[_code] = _codeAmount;
    }

    function DeleteDiscountCode(string calldata _code) external onlyOwner { 
        require(discountCodes[_code] > 0, DiscountCodeExist());

        delete discountCodes[_code];
    }

    function addProduct(string calldata _name, uint256 _id, uint256 _stock, uint256 _price) external {
        require(!isIdExist(_id), IdAlreadyExist());
        products.push(Product(_name, _id, _stock, _price));
    }

    function deleteProduct(uint256 _id) external onlyOwner {
        (bool status, uint256 index) = findIndexById(_id);
        require(status, IdDoesNotExist());

        products[index]= products[products.length -1];
        products.pop();
    }

    function updatePrice(uint256 _id, uint256 _price) external onlyOwner {
        //fing product for _id
        Product storage product = findProduct(_id);
        product.price = _price;
    }

    function updateStock(uint256 _id, uint256 _stock) external onlyOwner {
        Product storage product = findProduct(_id);
        product.stock = _stock;
    }

    function getTopSellingProduct() public view returns(uint256 topSellingProductId, uint256 topSales) {
        require(products.length > 0, ThereIsNoProducts());
        topSales = 0;
        topSellingProductId = products[0].id;

        for(uint256 i = 0; i < products.length; i++) {
            uint256 productId = products[i].id;
            uint256 sales = productPurchase[productId];

            if(sales > topSales) {
                topSales = sales;
                topSellingProductId = productId;
            }
        }
        return (topSellingProductId, topSales);
    }

    function getUserPurchases(address _buyer) public view returns(Purchase[] memory){
        return userPurchases[_buyer];
    }

    function getProducts() public view returns(Product[] memory){ 
        return products;
    }


    function getPrice(uint256 _id) public view returns(uint256) {
        return findProduct(_id).price;
    }

    function getStock(uint256 _id) public view returns(uint256) {
        return findProduct(_id).stock;
    }

    function getTotalRevenue() public view returns(uint256) {
        return totalRevenue;
    }

    function findProduct(uint256 _id) internal view returns(Product storage product){
        for(uint256 i = 0; i < products.length; i++){
            if(products[i].id == _id) {
                return products[i];
            } 
        }
        revert IdDoesNotExist();
    }

    function isIdExist(uint256 _id) internal view returns(bool) {
        for(uint256 i = 0; i < products.length; i++) {
            if(products[i].id == _id){
                return true;
            }
        }
        return false;
    }

    function findIndexById(uint256 _id) internal view returns(bool, uint256) {
        for(uint256 i = 0; i < products.length; i++) {
            if(products[i].id == _id) {
                return (true, i);
            }
        }
        return (false, 0);
    }
}
