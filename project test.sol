pragma solidity ^0.5.8;


//Define the smart contract
contract HDBRentalContract {

    // Parties involved
    address public landlordAddress; // 
    address public tenantAddress; //

    // HDB Property Details
	struct HDB {
		string name; // name of the HDB
		string addr; // address of the HDB
		uint room; // No. of room available for rent
		bool rented;
		string furnishing; // unfurnished/ semi-furnished/ fully-furnished w details
		uint rentInterval; // interval in days for the rent amount
		uint rentAmount; // 
		uint tenantWarning; // tracks the count for warning given to tenant
		uint warningLimit; // threshold limit for warning. Once excess tenant can be dismissed
		uint dueDate; // unit timestamp for the dueDate
		address tenantAddress; // tenant wallet address
		}


// Payment
	struct MonthlyRentStatus {
		uint rentAmount; // Monthly rent amount to be paid (includes utilities)
		uint amountDeposit; // Deposit and dispute amount if furniture spoil
		uint validationDate; // unix timestamp at which the rent was paid
		bool rented; // rent status
		string disputeStatement; //a statement to indicate dispute amount if furniture spoil

	}


// Lease term
	struct leaseTerm {
	uint leaseStartDate; // Start date of the lease (Unix timestamp)
    uint leaseEndDate; // End date of the lease (Unix timestamp)
	uint rentInterval; // interval in days for the rent amount

	}



// Rental status
    bool public isLeaseActive; // True: not available False: available for rent


 
	HDB public hdb; // instance of HDB struct
	address payable public landlord; // wallet address of contract/property owner
	uint private warningTime = 0; // timestamp when the tenant gets warned.
	mapping(string => bool) public months;
	mapping(address => bool) public tenantRegistry; // storage for users other than owner registered as a prospect.
	mapping(string => MonthlyRentStatus) public rentInStore; // storage for rental status

	event Reg(address _from, bool _val); // event when user registers as a prospect
	event Confirmed(address _from, bool _val); // event when property gets set on rent.
	event RentPaid(string _month, uint _amount); // event when the rent payment transaction is complete.
	event RentWithdrawn(string _month, uint _amount); // event when rent is withdrawn from the contract.
	event TenantWarning(string _month, uint _warning); // event to warn the tenant about pending payment.
	event DismissTenantConfirmed(bool _confirmed); // event to confirm the dismissal of tenant.

 // constructor to initialise the contract
	constructor(string memory name, string memory addr, string memory furnishing, uint room, uint rentInterval, uint rentAmount, uint warningLimit) public {
		hdb = HDB({name: name, addr: addr, furnishing: furnishing, room: room, rented: false, rentInterval: rentInterval, rentAmount: rentAmount,
		warningLimit: warningLimit, tenantWarning: 0, dueDate: 0, tenantAddress: address(0) });
		landlord = msg.sender;
		setMonths();
	}

	function setMonths() private {
	    months["Jan"] = true;
	    months["Feb"] = true;
	    months["Mar"] = true;
	    months["Apr"] = true;
	    months["May"] = true;
	    months["Jun"] = true;
	    months["Jul"] = true;
	    months["Aug"] = true;
	    months["Sep"] = true;
	    months["Oct"] = true;
	    months["Nov"] = true;
	    months["Dec"] = true;
	}

	modifier onlyOwner {
        require(msg.sender == landlord, "Only owner is authorized");
        _;
    }

	modifier nonOwner {
        require(msg.sender != landlord, "Only non-owner is authorized");
        _;
    }

	modifier nonTenant {
        require(msg.sender == tenantAddress, "Only tenant is authorized");
        _;
    }

	modifier allowedMonths(string memory month) {
		require(months[month] == true, "Incorrect value of the month");
		_;
	}

// rent payment, which also sets the next due date
	function payRent(string calldata  month) external payable nonTenant allowedMonths(month) returns (bool success) {
		require(rentInStore[month].rented == false,
        "Rent already paid"); // use require & not if statement, since function is payable & transaction should get reverted in invalid case.
		require(msg.sender == tenantAddress, 
		"Only tenant can pay rent");
		require(msg.value == hdb.rentAmount,
        "Incorrect rent amount");
		rentInStore[month].rentAmount = msg.value;
		rentInStore[month].rented = true;
		rentInStore[month].validationDate = now;
		hdb.dueDate = (block.number + (hdb.rentInterval * 6400 *15)); // calculate end time as 6400 blocks from the current block and a block time of 15 seconds
		hdb.tenantWarning = 0;
		emit RentPaid(month, msg.value);
		return true;
	}

	// provides the rent status based on given month
	function getRentStatus(string calldata month) external allowedMonths(month) view returns(uint amount, uint date, bool status) {
		MonthlyRentStatus memory rentStatus = rentInStore[month];
		return (
			rentStatus.rentAmount,
			rentStatus.validationDate,
			rentStatus.rented
		);

	}

	// an api for property owner to withdraw the rent amount from smart contract.
	function withdrawRent(string calldata month) external onlyOwner allowedMonths(month) returns (bool success) {
		require(rentInStore[month].rentAmount <= address(this).balance,
         "Insufficient contract balance"); // This is a must condition.
		uint balance = rentInStore[month].rentAmount;
		if(balance == hdb.rentAmount) {
			landlord.transfer(balance);
			rentInStore[month].rentAmount = 0;
		}
		emit RentWithdrawn(month, hdb.rentAmount); // confirming the rent withdraw transaction.
		return true;
	}

	// when owner wants to warn the tenant about pending rent payment.
	function warnTenant(string calldata month) external onlyOwner allowedMonths(month) returns (bool success) {
		require(hdb.rented == true, "Tenant doesn't exists");
		if((rentInStore[month].rented == false) && (now > hdb.dueDate) && ((now - warningTime) > 172800000)) {
			hdb.tenantWarning++;
			warningTime = now;
			emit TenantWarning(month, hdb.tenantWarning);
			return true;
		}
		return false;
	}

// when warning limit has been crossed & owner wants to dismiss the tenant
	function dismissTenant() external onlyOwner returns (bool success) {
		require(hdb.tenantWarning > hdb.warningLimit,"Warning limit is below threshold");
		hdb.tenantAddress = address(0);
		hdb.rented = false;
		hdb.tenantWarning = 0;
		hdb.dueDate = 0;
		emit DismissTenantConfirmed(true);
		return true;
	}


 // Function to end the lease
    function endLease() public {
        require(msg.sender == landlordAddress, "Only the landlord can end the lease");
        require(isLeaseActive, "Lease is already inactive");

        // Additional logic for ending the lease (e.g., handle security deposit, update status, etc.)

        isLeaseActive = false;
    }

// Function to renew the lease
    function renewLease(uint newEndDate) view  public {
        require(msg.sender == tenantAddress, "Only the tenant can renew the lease");
        require(isLeaseActive, "Lease must be active to renew");

        // Update the lease end date
       newEndDate = newEndDate;

    }
}
