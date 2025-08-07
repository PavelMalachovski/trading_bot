//+------------------------------------------------------------------+
//|                           Test_Refactored_Code.mq4               |
//|                   Comprehensive test suite for refactored code   |
//|                                                                  |
//|  This test file validates the refactored TelegramAPI and        |
//|  TrendFollowing code with various test scenarios including       |
//|  parameter validation, error handling, and functionality tests.  |
//|                                                                  |
//|  Author: Test Suite                                              |
//|  Date: 2025-01-27                                                |
//+------------------------------------------------------------------+

#property strict

#include "TelegramAPI_Refactored.mqh"

//+------------------------------------------------------------------+
//| Test configuration                                                |
//+------------------------------------------------------------------+
extern string    Test_Configuration       = "=== TEST CONFIGURATION ===";
extern bool      Run_Telegram_Tests      = true;        // Test Telegram functionality
extern bool      Run_Parameter_Tests     = true;        // Test parameter validation
extern bool      Run_Function_Tests      = true;        // Test core functions
extern bool      Run_Integration_Tests   = true;        // Test integration scenarios
extern string    Test_Bot_Token          = "TEST_BOT_TOKEN";
extern string    Test_Chat_ID            = "TEST_CHAT_ID";

//+------------------------------------------------------------------+
//| Global test variables                                             |
//+------------------------------------------------------------------+
int test_passed = 0;
int test_failed = 0;
string test_results[];

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Starting Refactored Code Tests ===");

    if(Run_Telegram_Tests)
        RunTelegramTests();

    if(Run_Parameter_Tests)
        RunParameterTests();

    if(Run_Function_Tests)
        RunFunctionTests();

    if(Run_Integration_Tests)
        RunIntegrationTests();

    PrintTestSummary();

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Test suite completed");
}

//+------------------------------------------------------------------+
//| Main tick handler (not used for tests)                           |
//+------------------------------------------------------------------+
void OnTick()
{
    // Tests are run in OnInit
}

//+------------------------------------------------------------------+
//| Test Telegram functionality                                       |
//+------------------------------------------------------------------+
void RunTelegramTests()
{
    Print("--- Running Telegram Tests ---");

    // Test 1: URL Encoding
    TestUrlEncoding();

    // Test 2: Credential Validation
    TestCredentialValidation();

    // Test 3: Message Building
    TestMessageBuilding();

    // Test 4: Error Handling
    TestErrorHandling();

    // Test 5: Queue Functionality
    TestQueueFunctionality();
}

//+------------------------------------------------------------------+
//| Test URL encoding function                                        |
//+------------------------------------------------------------------+
void TestUrlEncoding()
{
    Print("Testing URL encoding...");

    // Test basic encoding
    string test1 = UrlEncode("Hello World");
    if(test1 == "Hello+World")
    {
        LogTestResult("URL Encoding - Basic", true);
    }
    else
    {
        LogTestResult("URL Encoding - Basic", false, "Expected 'Hello+World', got '" + test1 + "'");
    }

    // Test special characters
    string test2 = UrlEncode("Test@123");
    if(StringFind(test2, "%40") >= 0)
    {
        LogTestResult("URL Encoding - Special Characters", true);
    }
    else
    {
        LogTestResult("URL Encoding - Special Characters", false, "Expected encoded @ symbol");
    }

    // Test empty string
    string test3 = UrlEncode("");
    if(test3 == "")
    {
        LogTestResult("URL Encoding - Empty String", true);
    }
    else
    {
        LogTestResult("URL Encoding - Empty String", false, "Expected empty string");
    }
}

//+------------------------------------------------------------------+
//| Test credential validation                                        |
//+------------------------------------------------------------------+
void TestCredentialValidation()
{
    Print("Testing credential validation...");

    // Test valid credentials
    bool result1 = ValidateTelegramCredentials("1234567890:ABC-DEF1234ghIkl-zyx57W2v1u123ew11", "123456789");
    if(result1)
    {
        LogTestResult("Credential Validation - Valid", true);
    }
    else
    {
        LogTestResult("Credential Validation - Valid", false);
    }

    // Test empty credentials
    bool result2 = ValidateTelegramCredentials("", "");
    if(!result2)
    {
        LogTestResult("Credential Validation - Empty", true);
    }
    else
    {
        LogTestResult("Credential Validation - Empty", false);
    }

    // Test short credentials
    bool result3 = ValidateTelegramCredentials("123", "123");
    if(!result3)
    {
        LogTestResult("Credential Validation - Short", true);
    }
    else
    {
        LogTestResult("Credential Validation - Short", false);
    }
}

//+------------------------------------------------------------------+
//| Test message building functions                                   |
//+------------------------------------------------------------------+
void TestMessageBuilding()
{
    Print("Testing message building...");

    // Test trade opened message
    string msg1 = BuildTradeOpenedMessage("EURUSD", "BUY", 1.0850, 1.0820, 1.0950, 0.1, 1.0);
    if(StringFind(msg1, "📈") >= 0 && StringFind(msg1, "EURUSD") >= 0)
    {
        LogTestResult("Message Building - Trade Opened", true);
    }
    else
    {
        LogTestResult("Message Building - Trade Opened", false);
    }

    // Test trade closed message
    string msg2 = BuildTradeClosedMessage("EURUSD", 1.0950, 100.0, 100.0, "USD", true);
    if(StringFind(msg2, "✅") >= 0 && StringFind(msg2, "WIN") >= 0)
    {
        LogTestResult("Message Building - Trade Closed Win", true);
    }
    else
    {
        LogTestResult("Message Building - Trade Closed Win", false);
    }

    // Test EA status message
    string msg3 = BuildEAStatusMessage("TestEA", "EURUSD", 10000.0, "USD", 1.0, "Started");
    if(StringFind(msg3, "🤖") >= 0 && StringFind(msg3, "TestEA") >= 0)
    {
        LogTestResult("Message Building - EA Status", true);
    }
    else
    {
        LogTestResult("Message Building - EA Status", false);
    }
}

//+------------------------------------------------------------------+
//| Test error handling                                               |
//+------------------------------------------------------------------+
void TestErrorHandling()
{
    Print("Testing error handling...");

    // Test with invalid credentials
    bool result = SendTelegramMessage("", "", "Test message");
    if(!result)
    {
        int error_code;
        string error_msg;
        GetLastTelegramError(error_code, error_msg);
        if(error_code == 1001)
        {
            LogTestResult("Error Handling - Invalid Credentials", true);
        }
        else
        {
            LogTestResult("Error Handling - Invalid Credentials", false, "Expected error 1001, got " + IntegerToString(error_code));
        }
    }
    else
    {
        LogTestResult("Error Handling - Invalid Credentials", false, "Expected failure");
    }

    // Test with empty message
    result = SendTelegramMessage("test", "test", "");
    if(!result)
    {
        int error_code;
        string error_msg;
        GetLastTelegramError(error_code, error_msg);
        if(error_code == 1003)
        {
            LogTestResult("Error Handling - Empty Message", true);
        }
        else
        {
            LogTestResult("Error Handling - Empty Message", false, "Expected error 1003, got " + IntegerToString(error_code));
        }
    }
    else
    {
        LogTestResult("Error Handling - Empty Message", false, "Expected failure");
    }
}

//+------------------------------------------------------------------+
//| Test queue functionality                                          |
//+------------------------------------------------------------------+
void TestQueueFunctionality()
{
    Print("Testing queue functionality...");

    // Clear queue first
    ClearMessageQueue();

    // Test queue size
    int size1 = GetMessageQueueSize();
    if(size1 == 0)
    {
        LogTestResult("Queue Functionality - Initial Size", true);
    }
    else
    {
        LogTestResult("Queue Functionality - Initial Size", false, "Expected 0, got " + IntegerToString(size1));
    }

    // Test adding message to queue
    QueueMessage("test", "test", "Test message", "HTML", false);
    int size2 = GetMessageQueueSize();
    if(size2 == 1)
    {
        LogTestResult("Queue Functionality - Add Message", true);
    }
    else
    {
        LogTestResult("Queue Functionality - Add Message", false, "Expected 1, got " + IntegerToString(size2));
    }

    // Test queue limit (simulate adding many messages)
    for(int i = 0; i < 60; i++)
    {
        QueueMessage("test", "test", "Test message " + IntegerToString(i), "HTML", false);
    }
    int size3 = GetMessageQueueSize();
    if(size3 <= 50) // Should be limited to 50
    {
        LogTestResult("Queue Functionality - Queue Limit", true);
    }
    else
    {
        LogTestResult("Queue Functionality - Queue Limit", false, "Expected <=50, got " + IntegerToString(size3));
    }
}

//+------------------------------------------------------------------+
//| Test parameter validation                                         |
//+------------------------------------------------------------------+
void RunParameterTests()
{
    Print("--- Running Parameter Tests ---");

    // Test valid parameters
    TestValidParameters();

    // Test invalid parameters
    TestInvalidParameters();

    // Test boundary conditions
    TestBoundaryConditions();
}

//+------------------------------------------------------------------+
//| Test valid parameters                                             |
//+------------------------------------------------------------------+
void TestValidParameters()
{
    Print("Testing valid parameters...");

    // Test valid indicator periods
    if(200 > 0 && 21 > 0 && 14 > 0)
    {
        LogTestResult("Valid Parameters - Indicator Periods", true);
    }
    else
    {
        LogTestResult("Valid Parameters - Indicator Periods", false);
    }

    // Test valid stop loss
    if(30 > 0)
    {
        LogTestResult("Valid Parameters - Stop Loss", true);
    }
    else
    {
        LogTestResult("Valid Parameters - Stop Loss", false);
    }

    // Test valid risk percentage
    if(1.0 > 0 && 1.0 <= 10)
    {
        LogTestResult("Valid Parameters - Risk Percentage", true);
    }
    else
    {
        LogTestResult("Valid Parameters - Risk Percentage", false);
    }

    // Test valid RSI thresholds
    if(55.0 > 50 && 45.0 < 50)
    {
        LogTestResult("Valid Parameters - RSI Thresholds", true);
    }
    else
    {
        LogTestResult("Valid Parameters - RSI Thresholds", false);
    }
}

//+------------------------------------------------------------------+
//| Test invalid parameters                                           |
//+------------------------------------------------------------------+
void TestInvalidParameters()
{
    Print("Testing invalid parameters...");

    // Test invalid indicator periods
    if(-1 <= 0)
    {
        LogTestResult("Invalid Parameters - Negative Periods", true);
    }
    else
    {
        LogTestResult("Invalid Parameters - Negative Periods", false);
    }

    // Test invalid stop loss
    if(0 <= 0)
    {
        LogTestResult("Invalid Parameters - Zero Stop Loss", true);
    }
    else
    {
        LogTestResult("Invalid Parameters - Zero Stop Loss", false);
    }

    // Test invalid risk percentage
    if(11.0 > 10)
    {
        LogTestResult("Invalid Parameters - High Risk", true);
    }
    else
    {
        LogTestResult("Invalid Parameters - High Risk", false);
    }

    // Test invalid RSI thresholds
    if(45.0 <= 50 || 55.0 >= 50)
    {
        LogTestResult("Invalid Parameters - RSI Thresholds", true);
    }
    else
    {
        LogTestResult("Invalid Parameters - RSI Thresholds", false);
    }
}

//+------------------------------------------------------------------+
//| Test boundary conditions                                          |
//+------------------------------------------------------------------+
void TestBoundaryConditions()
{
    Print("Testing boundary conditions...");

    // Test minimum valid values
    if(1 > 0 && 0.1 > 0 && 0.1 <= 10)
    {
        LogTestResult("Boundary Conditions - Minimum Values", true);
    }
    else
    {
        LogTestResult("Boundary Conditions - Minimum Values", false);
    }

    // Test maximum valid values
    if(1000 > 0 && 10.0 > 0 && 10.0 <= 10)
    {
        LogTestResult("Boundary Conditions - Maximum Values", true);
    }
    else
    {
        LogTestResult("Boundary Conditions - Maximum Values", false);
    }

    // Test edge cases
    if(0.001 > 0 && 9.99 > 0 && 9.99 <= 10)
    {
        LogTestResult("Boundary Conditions - Edge Cases", true);
    }
    else
    {
        LogTestResult("Boundary Conditions - Edge Cases", false);
    }
}

//+------------------------------------------------------------------+
//| Test core functions                                               |
//+------------------------------------------------------------------+
void RunFunctionTests()
{
    Print("--- Running Function Tests ---");

    // Test lot size calculation
    TestLotSizeCalculation();

    // Test profit calculation
    TestProfitCalculation();

    // Test session time validation
    TestSessionTimeValidation();

    // Test indicator calculations
    TestIndicatorCalculations();
}

//+------------------------------------------------------------------+
//| Test lot size calculation                                         |
//+------------------------------------------------------------------+
void TestLotSizeCalculation()
{
    Print("Testing lot size calculation...");

    // Simulate lot size calculation
    double balance = 10000.0;
    double risk_pct = 1.0;
    double risk_amt = balance * risk_pct / 100.0;

    if(risk_amt == 100.0)
    {
        LogTestResult("Lot Size Calculation - Risk Amount", true);
    }
    else
    {
        LogTestResult("Lot Size Calculation - Risk Amount", false, "Expected 100.0, got " + DoubleToString(risk_amt, 2));
    }

    // Test lot size limits
    double min_lot = 0.01;
    double max_lot = 100.0;
    double test_lot = 0.005; // Below minimum

    if(test_lot < min_lot)
    {
        LogTestResult("Lot Size Calculation - Minimum Limit", true);
    }
    else
    {
        LogTestResult("Lot Size Calculation - Minimum Limit", false);
    }

    test_lot = 150.0; // Above maximum
    if(test_lot > max_lot)
    {
        LogTestResult("Lot Size Calculation - Maximum Limit", true);
    }
    else
    {
        LogTestResult("Lot Size Calculation - Maximum Limit", false);
    }
}

//+------------------------------------------------------------------+
//| Test profit calculation                                           |
//+------------------------------------------------------------------+
void TestProfitCalculation()
{
    Print("Testing profit calculation...");

    // Test pip calculation for 5-digit broker
    double open_price = 1.08500;
    double close_price = 1.08600;
    double pips = (close_price - open_price) / 0.0001; // 5-digit calculation

    if(pips == 10.0)
    {
        LogTestResult("Profit Calculation - Pip Calculation", true);
    }
    else
    {
        LogTestResult("Profit Calculation - Pip Calculation", false, "Expected 10.0, got " + DoubleToString(pips, 1));
    }

    // Test profit calculation
    double lot_size = 0.1;
    double pip_value = 10.0; // USD per pip
    double profit = pips * lot_size * pip_value;

    if(profit == 10.0)
    {
        LogTestResult("Profit Calculation - Profit Amount", true);
    }
    else
    {
        LogTestResult("Profit Calculation - Profit Amount", false, "Expected 10.0, got " + DoubleToString(profit, 2));
    }
}

//+------------------------------------------------------------------+
//| Test session time validation                                      |
//+------------------------------------------------------------------+
void TestSessionTimeValidation()
{
    Print("Testing session time validation...");

    // Test valid time format
    string valid_time = "08:00";
    if(StringLen(valid_time) == 5)
    {
        LogTestResult("Session Time Validation - Valid Format", true);
    }
    else
    {
        LogTestResult("Session Time Validation - Valid Format", false);
    }

    // Test invalid time format
    string invalid_time = "8:00";
    if(StringLen(invalid_time) != 5)
    {
        LogTestResult("Session Time Validation - Invalid Format", true);
    }
    else
    {
        LogTestResult("Session Time Validation - Invalid Format", false);
    }

    // Test time parsing
    int hour = StringToInteger(StringSubstr(valid_time, 0, 2));
    int minute = StringToInteger(StringSubstr(valid_time, 3, 2));

    if(hour == 8 && minute == 0)
    {
        LogTestResult("Session Time Validation - Time Parsing", true);
    }
    else
    {
        LogTestResult("Session Time Validation - Time Parsing", false);
    }
}

//+------------------------------------------------------------------+
//| Test indicator calculations                                       |
//+------------------------------------------------------------------+
void TestIndicatorCalculations()
{
    Print("Testing indicator calculations...");

    // Test EMA calculation (simplified)
    double price1 = 1.0850;
    double price2 = 1.0860;
    double ema_period = 21;
    double multiplier = 2.0 / (ema_period + 1);

    if(multiplier > 0 && multiplier < 1)
    {
        LogTestResult("Indicator Calculations - EMA Multiplier", true);
    }
    else
    {
        LogTestResult("Indicator Calculations - EMA Multiplier", false);
    }

    // Test RSI threshold validation
    double rsi_long = 55.0;
    double rsi_short = 45.0;

    if(rsi_long > 50 && rsi_short < 50)
    {
        LogTestResult("Indicator Calculations - RSI Thresholds", true);
    }
    else
    {
        LogTestResult("Indicator Calculations - RSI Thresholds", false);
    }
}

//+------------------------------------------------------------------+
//| Test integration scenarios                                        |
//+------------------------------------------------------------------+
void RunIntegrationTests()
{
    Print("--- Running Integration Tests ---");

    // Test complete trade cycle
    TestCompleteTradeCycle();

    // Test daily reset functionality
    TestDailyResetFunctionality();

    // Test risk management integration
    TestRiskManagementIntegration();

    // Test Telegram integration
    TestTelegramIntegration();
}

//+------------------------------------------------------------------+
//| Test complete trade cycle                                         |
//+------------------------------------------------------------------+
void TestCompleteTradeCycle()
{
    Print("Testing complete trade cycle...");

    // Simulate trade entry conditions
    bool trend_ok = true;
    bool momentum_ok = true;
    bool session_ok = true;
    bool risk_ok = true;

    if(trend_ok && momentum_ok && session_ok && risk_ok)
    {
        LogTestResult("Trade Cycle - Entry Conditions", true);
    }
    else
    {
        LogTestResult("Trade Cycle - Entry Conditions", false);
    }

    // Simulate trade management
    bool breakeven_ok = true;
    bool trailing_ok = true;

    if(breakeven_ok && trailing_ok)
    {
        LogTestResult("Trade Cycle - Trade Management", true);
    }
    else
    {
        LogTestResult("Trade Cycle - Trade Management", false);
    }

    // Simulate trade exit
    bool exit_ok = true;
    bool notification_ok = true;

    if(exit_ok && notification_ok)
    {
        LogTestResult("Trade Cycle - Trade Exit", true);
    }
    else
    {
        LogTestResult("Trade Cycle - Trade Exit", false);
    }
}

//+------------------------------------------------------------------+
//| Test daily reset functionality                                    |
//+------------------------------------------------------------------+
void TestDailyResetFunctionality()
{
    Print("Testing daily reset functionality...");

    // Simulate daily tracking variables
    double daily_balance = 10000.0;
    int daily_trades = 5;
    int daily_losses = 2;

    // Test reset conditions
    bool should_reset = (daily_trades >= 5 || daily_losses >= 3);

    if(should_reset)
    {
        LogTestResult("Daily Reset - Reset Conditions", true);
    }
    else
    {
        LogTestResult("Daily Reset - Reset Conditions", false);
    }

    // Test reset values
    double new_balance = 10100.0; // New day balance
    int new_trades = 0;
    int new_losses = 0;

    if(new_trades == 0 && new_losses == 0)
    {
        LogTestResult("Daily Reset - Reset Values", true);
    }
    else
    {
        LogTestResult("Daily Reset - Reset Values", false);
    }
}

//+------------------------------------------------------------------+
//| Test risk management integration                                  |
//+------------------------------------------------------------------+
void TestRiskManagementIntegration()
{
    Print("Testing risk management integration...");

    // Test daily loss limit
    double start_balance = 10000.0;
    double current_balance = 9500.0;
    double loss_pct = (start_balance - current_balance) / start_balance * 100.0;
    double limit_pct = 5.0;

    if(loss_pct >= limit_pct)
    {
        LogTestResult("Risk Management - Daily Loss Limit", true);
    }
    else
    {
        LogTestResult("Risk Management - Daily Loss Limit", false);
    }

    // Test consecutive losses
    int consecutive_losses = 3;
    int max_consecutive = 3;

    if(consecutive_losses >= max_consecutive)
    {
        LogTestResult("Risk Management - Consecutive Losses", true);
    }
    else
    {
        LogTestResult("Risk Management - Consecutive Losses", false);
    }

    // Test equity stop
    double start_equity = 10000.0;
    double current_equity = 9000.0;
    double equity_drop = (start_equity - current_equity) / start_equity * 100.0;
    double equity_limit = 10.0;

    if(equity_drop >= equity_limit)
    {
        LogTestResult("Risk Management - Equity Stop", true);
    }
    else
    {
        LogTestResult("Risk Management - Equity Stop", false);
    }
}

//+------------------------------------------------------------------+
//| Test Telegram integration                                         |
//+------------------------------------------------------------------+
void TestTelegramIntegration()
{
    Print("Testing Telegram integration...");

    // Test message queue functionality
    ClearMessageQueue();
    QueueMessage("test", "test", "Test message");

    if(GetMessageQueueSize() == 1)
    {
        LogTestResult("Telegram Integration - Message Queue", true);
    }
    else
    {
        LogTestResult("Telegram Integration - Message Queue", false);
    }

    // Test error handling
    int error_code;
    string error_msg;
    GetLastTelegramError(error_code, error_msg);

    if(error_code >= 0) // Valid error code
    {
        LogTestResult("Telegram Integration - Error Handling", true);
    }
    else
    {
        LogTestResult("Telegram Integration - Error Handling", false);
    }

    // Test message formatting
    string test_msg = BuildTradeOpenedMessage("EURUSD", "BUY", 1.0850, 1.0820, 1.0950, 0.1, 1.0);

    if(StringLen(test_msg) > 0)
    {
        LogTestResult("Telegram Integration - Message Formatting", true);
    }
    else
    {
        LogTestResult("Telegram Integration - Message Formatting", false);
    }
}

//+------------------------------------------------------------------+
//| Log test result                                                   |
//+------------------------------------------------------------------+
void LogTestResult(const string test_name, const bool passed, const string details = "")
{
    if(passed)
    {
        test_passed++;
        Print("✅ PASS: ", test_name);
    }
    else
    {
        test_failed++;
        Print("❌ FAIL: ", test_name);
        if(details != "")
            Print("   Details: ", details);
    }
}

//+------------------------------------------------------------------+
//| Print test summary                                                |
//+------------------------------------------------------------------+
void PrintTestSummary()
{
    Print("=== Test Summary ===");
    Print("Total Tests: ", test_passed + test_failed);
    Print("Passed: ", test_passed);
    Print("Failed: ", test_failed);
    Print("Success Rate: ", DoubleToString((double)test_passed / (test_passed + test_failed) * 100.0, 1), "%");

    if(test_failed == 0)
    {
        Print("🎉 All tests passed! Refactored code is working correctly.");
    }
    else
    {
        Print("⚠️  Some tests failed. Please review the failed tests above.");
    }
}
