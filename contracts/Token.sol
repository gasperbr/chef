pragma solidity >=0.8.0;

contract Token {

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;

	uint256 public totalSupply = 0;

    string public constant name = "TOKEN";
    uint8 public constant decimals = 18;
    string public constant symbol = "TKN";

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        balances[_to] += _value;
        balances[_from] -= _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return type(uint256).max;
    }

	function mint(address user, uint256 amount) public {
		balances[user] += amount;
		totalSupply += amount;
	}
}