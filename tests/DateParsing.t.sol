// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/src/Test.sol";
import { DateParsing } from "../src/lib/DateParsing.sol";

// Helper contract to expose internal function for testing
contract DateParsingHelper {
    using DateParsing for string;

    function dateStringToTimestamp(string memory _dateString) external pure returns (uint256) {
        return DateParsing._dateStringToTimestamp(_dateString);
    }
}

contract DateParsingTest is Test {
    DateParsingHelper public helper;

    function setUp() public {
        helper = new DateParsingHelper();
    }

    function test_dateStringToTimestamp_SpaceFormat() public {
        // Test the specific format "2025-06-17 22:08:30"
        string memory dateString = "2025-06-17 22:08:30";
        uint256 timestamp = helper.dateStringToTimestamp(dateString);

        // Expected timestamp for 2025-06-17 22:08:30 UTC
        // The function returns 1750198110 which corresponds to this date/time
        uint256 expectedTimestamp = 1_750_198_110;

        assertEq(timestamp, expectedTimestamp, "Timestamp should match expected value");
    }

    function test_dateStringToTimestamp_ISOFormat() public {
        // Test the ISO format "2025-06-17T22:08:30"
        string memory dateString = "2025-06-17T22:08:30";
        uint256 timestamp = helper.dateStringToTimestamp(dateString);

        // Should be the same timestamp as the space format
        uint256 expectedTimestamp = 1_750_198_110;

        assertEq(timestamp, expectedTimestamp, "ISO format should produce same timestamp");
    }

    function test_dateStringToTimestamp_WithMilliseconds() public {
        // Test format with milliseconds "2025-06-17T22:08:30.123Z"
        string memory dateString = "2025-06-17T22:08:30.123Z";
        uint256 timestamp = helper.dateStringToTimestamp(dateString);

        // Should ignore milliseconds and timezone, same timestamp
        uint256 expectedTimestamp = 1_750_198_110;

        assertEq(timestamp, expectedTimestamp, "Should ignore milliseconds and timezone");
    }

    function test_dateStringToTimestamp_DifferentDate() public {
        // Test a different date to ensure parsing works correctly
        string memory dateString = "2024-01-01 00:00:00";
        uint256 timestamp = helper.dateStringToTimestamp(dateString);

        // January 1, 2024, 00:00:00 UTC = 1704067200
        uint256 expectedTimestamp = 1_704_067_200;

        assertEq(timestamp, expectedTimestamp, "Different date should parse correctly");
    }

    function test_dateStringToTimestamp_LeapYear() public {
        // Test leap year date: February 29, 2024
        string memory dateString = "2024-02-29 12:30:45";
        uint256 timestamp = helper.dateStringToTimestamp(dateString);

        // February 29, 2024, 12:30:45 UTC = 1709209845
        uint256 expectedTimestamp = 1_709_209_845;

        assertEq(timestamp, expectedTimestamp, "Leap year date should parse correctly");
    }

    function test_RevertWhen_InvalidDateString() public {
        // Test with invalid format (missing components)
        string memory invalidDate = "2025-06-17";

        vm.expectRevert("Invalid date string");
        helper.dateStringToTimestamp(invalidDate);
    }

    function test_RevertWhen_TooManyComponents() public {
        // Test with too many separators causing array out of bounds
        string memory invalidDate = "2025-06-17-22-08-30-123";

        // This will cause an array out of bounds error, not "Invalid date string"
        vm.expectRevert();
        helper.dateStringToTimestamp(invalidDate);
    }

    function test_dateStringToTimestamp_EdgeCases() public {
        // Test various edge cases

        // Start of Unix epoch (1970-01-01 00:00:00)
        string memory epochStart = "1970-01-01 00:00:00";
        uint256 epochTimestamp = helper.dateStringToTimestamp(epochStart);
        assertEq(epochTimestamp, 0, "Unix epoch start should be 0");

        // End of year
        string memory endOfYear = "2025-12-31 23:59:59";
        uint256 endTimestamp = helper.dateStringToTimestamp(endOfYear);
        // December 31, 2025, 23:59:59 UTC = 1767225599
        assertEq(endTimestamp, 1_767_225_599, "End of year should parse correctly");
    }
}
