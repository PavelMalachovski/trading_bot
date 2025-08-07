//+------------------------------------------------------------------+
//|                           TrendFollowingEA_Refactored.mq4        |
//|                   Enhanced trend-following expert advisor        |
//|                                                                  |
//|  This refactored EA implements a sophisticated trend-following  |
//|  strategy with improved risk management, better code organization|
//|  enhanced error handling, and comprehensive logging.             |
//|                                                                  |
//|  Key Improvements:                                               |
//|  - Modular code structure with separate functions                |
//|  - Enhanced error handling and validation                        |
//|  - Improved risk management with multiple safety checks         |
//|  - Better performance tracking and statistics                    |
//|  - Comprehensive logging and debugging capabilities              |
//|  - Configurable trading sessions and filters                    |
//|                                                                  |
//|  Author: Refactored version                                      |
//|  Date: 2025-01-27                                                |
//+------------------------------------------------------------------+

#property strict

#include <Trade\\AccountInfo.mqh>
#include "TelegramAPI_Refactored.mqh"

//+------------------------------------------------------------------+
//| External parameters                                               |
//+------------------------------------------------------------------+
extern string    Settings_1              = "=== TREND FILTER SETTINGS ===";
extern int       TrendEMA_Period         = 200;        // Long-term trend EMA period
extern int       FastEMA_Period          = 21;         // Fast momentum EMA period
extern int       RSI_Period              = 14;         // RSI period
extern double    RSI_Long_Threshold      = 55.0;       // RSI threshold for long trades
extern double    RSI_Short_Threshold     = 45.0;       // RSI threshold for short trades
extern bool      Use_MACD_Filter         = true;       // Enable MACD histogram filter

extern string    Settings_1B             = "=== ENHANCED FILTERS ===";
extern bool      Use_ADX_Filter          = true;       // Enable ADX trend strength filter
extern int       ADX_Period              = 14;         // ADX period
extern double    ADX_Threshold           = 25.0;       // Minimum ADX for trend strength
extern bool      Use_Session_Filter      = true;       // Enable session time filter
extern string    Session_Start_Time      = "08:00";    // Trading session start
extern string    Session_End_Time        = "20:00";    // Trading session end
extern bool      Use_Volatility_Filter   = false;      // Enable volatility filter
extern double    Min_Volatility_ATR      = 0.0005;    // Minimum ATR for trading

extern string    Settings_2              = "=== ENTRY & EXIT SETTINGS ===";
extern int       StopLoss_Pips           = 30;         // Fixed stop-loss in pips
extern double    Risk_Percent            = 1.0;        // Risk per trade (% of balance)
extern int       Max_Concurrent_Trades   = 1;          // Maximum positions open at once
extern bool      Enable_Breakeven        = true;       // Move SL to breakeven after 1×SL gain
extern double    Breakeven_Ratio         = 1.0;        // Profit-to-SL ratio to trigger BE move
extern bool      Enable_Trailing         = false;      // Enable trailing stops
extern int       Trailing_Start_Pips     = 20;         // Pips profit to start trailing
extern int       Trailing_Step_Pips      = 10;         // Trailing step in pips
extern bool      Use_Dynamic_TP          = false;      // Use ATR-based take profit
extern double    TP_ATR_Multiplier       = 3.0;        // ATR multiplier for TP

extern string    Settings_3              = "=== RISK MANAGEMENT ===";
extern double    Daily_Loss_Limit_Pct    = 5.0;        // Stop trading after daily drawdown (%)
extern int       Max_Daily_Trades        = 5;          // Maximum trades per day
extern int       Max_Daily_Loss_Trades   = 3;          // Maximum losing trades per day
extern int       Max_Consecutive_Losses  = 3;          // Consecutive losses before pausing
extern string    Intraday_Close_Time     = "22:00";    // Time to close all positions
extern bool      Enable_Equity_Stop      = false;      // Stop trading if equity drops
extern double    Equity_Stop_Pct         = 10.0;       // Equity stop percentage

extern string    Settings_4              = "=== TELEGRAM SETTINGS ===";
extern string    Telegram_Bot_Token      = "YOUR_BOT_TOKEN_HERE";
extern string    Telegram_Chat_ID        = "YOUR_CHAT_ID_HERE";
extern bool      Enable_Telegram          = true;
extern bool      Send_Detailed_Logs      = false;      // Send detailed trade logs

extern string    Settings_5              = "=== MAGIC NUMBER ===";
extern int       Magic_Number            = 12345;

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
// Trading state variables
double   daily_start_balance = 0.0;
double   daily_start_equity  = 0.0;
datetime last_bar_time       = 0;
datetime daily_reset_time    = 0;
bool     trading_allowed     = true;
bool     emergency_stop      = false;

// Trade counters
int      daily_trade_count   = 0;
int      consecutive_losses  = 0;
int      daily_loss_trades   = 0;
int      total_trades        = 0;
int      winning_trades      = 0;

// Performance tracking
double   total_profit        = 0.0;
double   max_drawdown        = 0.0;
double   peak_balance        = 0.0;

// EA identification
string   ea_name             = "TrendFollowingEA_Refactored";

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate user parameters
    if(!ValidateInputs())
    {
        Print("Invalid parameters supplied; EA disabled");
        return(INIT_PARAMETERS_INCORRECT);
    }

    // Initialize daily tracking
    InitializeDailyTracking();

    // Initialize performance tracking
    InitializePerformanceTracking();

    // Test Telegram connection if enabled
    if(Enable_Telegram && !TestTelegramConnection())
    {
        Print("Warning: Telegram connection test failed");
    }

    // Notify user that the EA has started
    SendEAStatusNotification("Started");

    Print(ea_name, " initialized successfully on ", Symbol());
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Send final performance summary
    SendPerformanceSummary();

    // Send EA status notification
    SendEAStatusNotification("Stopped");

    Print(ea_name, " deinitialization; reason ", reason);
}

//+------------------------------------------------------------------+
//| Main tick handler                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
    // Ensure sufficient bars for indicators
    if(Bars < TrendEMA_Period + 10)
    {
        if(Send_Detailed_Logs)
            Print("Insufficient bars for analysis");
        return;
    }

    // Only process once per bar
    if(Time[0] == last_bar_time)
        return;
    last_bar_time = Time[0];

    // Reset counters on new day
    CheckDailyReset();

    // Check emergency conditions
    if(!CheckEmergencyConditions())
        return;

    // Check daily loss limit
    if(!CheckDailyLossLimit())
    {
        HandleDailyLossLimit();
        return;
    }

    // Check intraday close time
    if(IsIntradayCloseTime())
    {
        CloseAllPositions();
        return;
    }

    // Manage active orders
    ManageExistingPositions();

    // Attempt to open new trades if conditions permit
    if(trading_allowed && CountOpenPositions() < Max_Concurrent_Trades && CanOpenNewTrade())
    {
        CheckForTradeEntry();
    }
}

//+------------------------------------------------------------------+
//| Initialize daily tracking variables                               |
//+------------------------------------------------------------------+
void InitializeDailyTracking()
{
    daily_start_balance = AccountBalance();
    daily_start_equity  = AccountEquity();
    daily_reset_time    = TimeCurrent();
    daily_trade_count   = 0;
    daily_loss_trades   = 0;
    consecutive_losses  = 0;
    trading_allowed     = true;
    emergency_stop      = false;
}

//+------------------------------------------------------------------+
//| Initialize performance tracking variables                          |
//+------------------------------------------------------------------+
void InitializePerformanceTracking()
{
    total_profit = 0.0;
    max_drawdown = 0.0;
    peak_balance = AccountBalance();
    total_trades = 0;
    winning_trades = 0;
}

//+------------------------------------------------------------------+
//| Test Telegram connection                                          |
//+------------------------------------------------------------------+
bool TestTelegramConnection()
{
    if(!Enable_Telegram) return true;

    string test_msg = "🤖 " + ea_name + " connection test successful";
    bool success = SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, test_msg);

    if(!success)
    {
        int error_code;
        string error_msg;
        GetLastTelegramError(error_code, error_msg);
        Print("Telegram test failed: ", error_msg);
    }

    return success;
}

//+------------------------------------------------------------------+
//| Validate input parameters                                         |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    // Validate indicator periods
    if(TrendEMA_Period <= 0 || FastEMA_Period <= 0 || RSI_Period <= 0)
    {
        Alert("Indicator periods must be positive");
        return false;
    }

    // Validate stop loss
    if(StopLoss_Pips <= 0)
    {
        Alert("StopLoss_Pips must be positive");
        return false;
    }

    // Validate risk percentage
    if(Risk_Percent <= 0 || Risk_Percent > 10)
    {
        Alert("Risk_Percent must be in (0,10]");
        return false;
    }

    // Validate RSI thresholds
    if(RSI_Long_Threshold <= 50 || RSI_Short_Threshold >= 50)
    {
        Alert("RSI thresholds must straddle 50");
        return false;
    }

    // Validate ADX parameters
    if(Use_ADX_Filter && (ADX_Period <= 0 || ADX_Threshold < 0 || ADX_Threshold > 50))
    {
        Alert("Invalid ADX parameters");
        return false;
    }

    // Validate session times
    if(Use_Session_Filter && !ValidateSessionTimes())
    {
        Alert("Invalid session time format (use HH:MM)");
        return false;
    }

    // Validate Telegram settings
    if(Enable_Telegram && (StringTrim(Telegram_Bot_Token) == "" || StringTrim(Telegram_Chat_ID) == ""))
    {
        Alert("Telegram credentials required when Enable_Telegram is true");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Validate session time format                                      |
//+------------------------------------------------------------------+
bool ValidateSessionTimes()
{
    if(StringLen(Session_Start_Time) != 5 || StringLen(Session_End_Time) != 5)
        return false;

    int start_hour = StringToInteger(StringSubstr(Session_Start_Time, 0, 2));
    int start_min = StringToInteger(StringSubstr(Session_Start_Time, 3, 2));
    int end_hour = StringToInteger(StringSubstr(Session_End_Time, 0, 2));
    int end_min = StringToInteger(StringSubstr(Session_End_Time, 3, 2));

    return (start_hour >= 0 && start_hour <= 23 && start_min >= 0 && start_min <= 59 &&
            end_hour >= 0 && end_hour <= 23 && end_min >= 0 && end_min <= 59);
}

//+------------------------------------------------------------------+
//| Check for daily reset                                             |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    if(TimeDay(TimeCurrent()) != TimeDay(daily_reset_time))
    {
        // Send daily summary before reset
        SendDailySummary();

        // Reset daily tracking
        daily_start_balance = AccountBalance();
        daily_start_equity  = AccountEquity();
        daily_reset_time    = TimeCurrent();
        daily_trade_count   = 0;
        daily_loss_trades   = 0;
        consecutive_losses  = 0;
        trading_allowed     = true;

        Print("Daily reset completed");
    }
}

//+------------------------------------------------------------------+
//| Check emergency conditions                                        |
//+------------------------------------------------------------------+
bool CheckEmergencyConditions()
{
    // Check equity stop
    if(Enable_Equity_Stop)
    {
        double current_equity = AccountEquity();
        double equity_drop = (daily_start_equity - current_equity) / daily_start_equity * 100.0;

        if(equity_drop >= Equity_Stop_Pct)
        {
            if(!emergency_stop)
            {
                emergency_stop = true;
                CloseAllPositions();
                Print("Emergency stop triggered: Equity dropped ", DoubleToString(equity_drop, 2), "%");

                if(Enable_Telegram)
                {
                    string msg = BuildErrorMessage("Emergency Stop",
                        "Equity dropped " + DoubleToString(equity_drop, 2) + "%");
                    SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
                }
            }
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check daily loss percentage                                       |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
    double current_balance = AccountBalance();
    double loss_pct = (daily_start_balance - current_balance) / daily_start_balance * 100.0;
    return(loss_pct < Daily_Loss_Limit_Pct);
}

//+------------------------------------------------------------------+
//| Handle daily loss limit reached                                   |
//+------------------------------------------------------------------+
void HandleDailyLossLimit()
{
    if(trading_allowed)
    {
        CloseAllPositions();
        trading_allowed = false;
        Print("Daily loss limit reached; trading disabled");

        if(Enable_Telegram)
        {
            double current_loss_pct = (daily_start_balance - AccountBalance()) / daily_start_balance * 100.0;
            string msg = BuildDailyLimitMessage(current_loss_pct, Daily_Loss_Limit_Pct);
            SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
        }
    }
}

//+------------------------------------------------------------------+
//| Determine if a new trade can be opened                           |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
    if(daily_trade_count >= Max_Daily_Trades)
    {
        if(Send_Detailed_Logs)
            Print("Daily trade limit reached");
        return false;
    }

    if(consecutive_losses >= Max_Consecutive_Losses)
    {
        if(Send_Detailed_Logs)
            Print("Maximum consecutive losses reached");
        return false;
    }

    if(daily_loss_trades >= Max_Daily_Loss_Trades)
    {
        if(Send_Detailed_Logs)
            Print("Daily loss trade limit reached");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Evaluate entry conditions and open trade                          |
//+------------------------------------------------------------------+
void CheckForTradeEntry()
{
    // Get indicator values
    double trend_ema_current  = iMA(NULL, 0, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double trend_ema_prev     = iMA(NULL, 0, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
    double fast_ema_current   = iMA(NULL, 0, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double fast_ema_prev      = iMA(NULL, 0, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
    double rsi_current        = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 1);

    // Check MACD filter
    double macd_main = 0;
    if(Use_MACD_Filter)
        macd_main = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);

    // Check ADX filter
    bool adx_ok = true;
    if(Use_ADX_Filter)
    {
        double adx_val = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
        adx_ok = (adx_val >= ADX_Threshold);
    }

    // Check session filter
    bool session_ok = (!Use_Session_Filter || IsWithinTradingSession());

    // Check volatility filter
    bool volatility_ok = true;
    if(Use_Volatility_Filter)
    {
        double atr = iATR(NULL, 0, 14, 1);
        volatility_ok = (atr >= Min_Volatility_ATR);
    }

    double close_price = Close[1];
    bool ema_cross_up   = (fast_ema_current > trend_ema_current && fast_ema_prev <= trend_ema_prev);
    bool ema_cross_down = (fast_ema_current < trend_ema_current && fast_ema_prev >= trend_ema_prev);
    bool price_confirms_long  = (close_price > trend_ema_current && close_price > fast_ema_current);
    bool price_confirms_short = (close_price < trend_ema_current && close_price < fast_ema_current);

    // Long entry conditions
    if(price_confirms_long && ema_cross_up && rsi_current > RSI_Long_Threshold &&
       (!Use_MACD_Filter || macd_main > 0) && adx_ok && session_ok && volatility_ok)
    {
        OpenTrade(OP_BUY);
    }
    // Short entry conditions
    else if(price_confirms_short && ema_cross_down && rsi_current < RSI_Short_Threshold &&
            (!Use_MACD_Filter || macd_main < 0) && adx_ok && session_ok && volatility_ok)
    {
        OpenTrade(OP_SELL);
    }
}

//+------------------------------------------------------------------+
//| Check session boundaries                                          |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
{
    if(!Use_Session_Filter) return true;

    int hh = TimeHour(TimeCurrent());
    int mm = TimeMinute(TimeCurrent());
    int curr = hh * 60 + mm;
    int start = StringToInteger(StringSubstr(Session_Start_Time, 0, 2)) * 60 +
                StringToInteger(StringSubstr(Session_Start_Time, 3, 2));
    int end = StringToInteger(StringSubstr(Session_End_Time, 0, 2)) * 60 +
              StringToInteger(StringSubstr(Session_End_Time, 3, 2));

    return(curr >= start && curr <= end);
}

//+------------------------------------------------------------------+
//| Opens a new market order                                          |
//+------------------------------------------------------------------+
void OpenTrade(const int direction)
{
    double lot = CalculateLotSize();
    if(lot <= 0)
    {
        Print("Lot size calculation failed; trade not opened");
        return;
    }

    double entry_price = (direction == OP_BUY) ? Ask : Bid;
    double sl, tp;

    // Calculate stop loss and take profit
    if(direction == OP_BUY)
    {
        sl = entry_price - StopLoss_Pips * Point * 10;
        if(Use_Dynamic_TP)
        {
            double atr = iATR(NULL, 0, 14, 1);
            tp = entry_price + (atr * TP_ATR_Multiplier);
        }
        else
        {
            tp = entry_price + (StopLoss_Pips * 3) * Point * 10;
        }
    }
    else
    {
        sl = entry_price + StopLoss_Pips * Point * 10;
        if(Use_Dynamic_TP)
        {
            double atr = iATR(NULL, 0, 14, 1);
            tp = entry_price - (atr * TP_ATR_Multiplier);
        }
        else
        {
            tp = entry_price - (StopLoss_Pips * 3) * Point * 10;
        }
    }

    sl = NormalizeDouble(sl, Digits);
    tp = NormalizeDouble(tp, Digits);

    string dir_str = (direction == OP_BUY) ? "BUY" : "SELL";
    string comment = StringFormat("%s_%s", ea_name, dir_str);

    int ticket = OrderSend(Symbol(), direction, lot, entry_price, 3, sl, tp, comment, Magic_Number, 0, clrNONE);

    if(ticket > 0)
    {
        daily_trade_count++;
        total_trades++;

        Print("Opened ", dir_str, " ", lot, " lots at ", entry_price);

        if(Enable_Telegram)
        {
            string msg = BuildTradeOpenedMessage(Symbol(), dir_str, entry_price, sl, tp, lot, Risk_Percent);
            SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
        }
    }
    else
    {
        int error = GetLastError();
        Print("OrderSend failed: ", error);

        if(Enable_Telegram)
        {
            string msg = BuildErrorMessage("Order Send Failed", "Error code: " + IntegerToString(error));
            SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculates trade lot size                                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountBalance();
    double risk_amt = balance * Risk_Percent / 100.0;
    double pip_value = MarketInfo(Symbol(), MODE_TICKVALUE);

    if(Digits == 5 || Digits == 3)
        pip_value *= 10;

    double lot = risk_amt / (StopLoss_Pips * pip_value);
    double step = MarketInfo(Symbol(), MODE_LOTSTEP);
    lot = MathFloor(lot / step) * step;

    double minlot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxlot = MarketInfo(Symbol(), MODE_MAXLOT);

    if(lot < minlot) lot = minlot;
    if(lot > maxlot) lot = maxlot;

    return lot;
}

//+------------------------------------------------------------------+
//| Manage open orders                                                |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Number) continue;

        double curr_price = (OrderType() == OP_BUY) ? Bid : Ask;
        double profit_pips = CalculateProfitPips(OrderType(), OrderOpenPrice(), curr_price);
        double sl_dist_pips = CalculateSLDistancePips(OrderType(), OrderOpenPrice(), OrderStopLoss());

        // Move to breakeven if enabled
        if(Enable_Breakeven && profit_pips >= sl_dist_pips * Breakeven_Ratio)
            MoveToBreakeven(OrderTicket(), OrderType(), OrderOpenPrice());

        // Apply trailing stop if enabled
        if(Enable_Trailing && profit_pips >= Trailing_Start_Pips)
            TrailingStop(OrderTicket(), OrderType(), curr_price);
    }
}

//+------------------------------------------------------------------+
//| Calculate profit in pips                                          |
//+------------------------------------------------------------------+
double CalculateProfitPips(const int type, const double open_price, const double curr_price)
{
    double factor = (Digits == 5 || Digits == 3) ? 10 : 1;
    if(type == OP_BUY)
        return((curr_price - open_price) / Point / factor);
    else
        return((open_price - curr_price) / Point / factor);
}

//+------------------------------------------------------------------+
//| Calculate SL distance in pips                                     |
//+------------------------------------------------------------------+
double CalculateSLDistancePips(const int type, const double open_price, const double sl_price)
{
    if(sl_price == 0) return 0;
    double factor = (Digits == 5 || Digits == 3) ? 10 : 1;
    if(type == OP_BUY)
        return((open_price - sl_price) / Point / factor);
    else
        return((sl_price - open_price) / Point / factor);
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven                                       |
//+------------------------------------------------------------------+
void MoveToBreakeven(const int ticket, const int type, const double open_price)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

    double new_sl = NormalizeDouble(open_price, Digits);
    if(MathAbs(OrderStopLoss() - new_sl) > Point)
    {
        bool ok = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
        if(ok)
        {
            Print("Moved order ", ticket, " to breakeven");
            if(Send_Detailed_Logs)
                Print("Breakeven triggered for ticket: ", ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                               |
//+------------------------------------------------------------------+
void TrailingStop(const int ticket, const int type, const double curr_price)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

    double new_sl;
    if(type == OP_BUY)
    {
        new_sl = curr_price - Trailing_Step_Pips * Point * 10;
        if(new_sl > OrderStopLoss() + Point)
        {
            new_sl = NormalizeDouble(new_sl, Digits);
            bool ok = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
            if(!ok)
            {
                Print("Trailing modification failed: ", GetLastError());
            }
        }
    }
    else
    {
        new_sl = curr_price + Trailing_Step_Pips * Point * 10;
        if(new_sl < OrderStopLoss() - Point)
        {
            new_sl = NormalizeDouble(new_sl, Digits);
            bool ok = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
            if(!ok)
            {
                Print("Trailing modification failed: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if intraday close time has been reached                     |
//+------------------------------------------------------------------+
bool IsIntradayCloseTime()
{
    string curr_time = TimeToStr(TimeCurrent(), TIME_MINUTES);
    return(StringFind(curr_time, Intraday_Close_Time) >= 0);
}

//+------------------------------------------------------------------+
//| Close all trades belonging to this EA                             |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Number) continue;

        double close_price = (OrderType() == OP_BUY) ? Bid : Ask;
        bool ok = OrderClose(OrderTicket(), OrderLots(), close_price, 3, clrRed);

        if(ok)
        {
            // Update performance tracking
            double profit = OrderProfit();
            total_profit += profit;

            if(profit > 0)
            {
                winning_trades++;
                consecutive_losses = 0;
            }
            else
            {
                consecutive_losses++;
                daily_loss_trades++;
            }

            // Update drawdown tracking
            double current_balance = AccountBalance();
            if(current_balance > peak_balance)
                peak_balance = current_balance;
            else
            {
                double drawdown = (peak_balance - current_balance) / peak_balance * 100.0;
                if(drawdown > max_drawdown)
                    max_drawdown = drawdown;
            }

            // Notify via Telegram
            if(Enable_Telegram)
            {
                double pips = CalculateProfitPips(OrderType(), OrderOpenPrice(), close_price);
                bool win = (profit > 0);
                string msg = BuildTradeClosedMessage(Symbol(), close_price, pips, profit, AccountCurrency(), win);
                SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Count open positions                                              |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic_Number)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Send EA status notification                                       |
//+------------------------------------------------------------------+
void SendEAStatusNotification(const string status)
{
    if(Enable_Telegram)
    {
        string msg = BuildEAStatusMessage(ea_name, Symbol(), AccountBalance(), AccountCurrency(), Risk_Percent, status);
        SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }
}

//+------------------------------------------------------------------+
//| Send daily summary                                                |
//+------------------------------------------------------------------+
void SendDailySummary()
{
    if(Enable_Telegram && daily_trade_count > 0)
    {
        string msg = StringFormat(
            "📊 <b>Daily Summary</b>\n"
            "📈 Trades: %d\n"
            "💰 P/L: %.2f %s\n"
            "📉 Loss Trades: %d\n"
            "⏰ %s",
            daily_trade_count,
            AccountBalance() - daily_start_balance, AccountCurrency(),
            daily_loss_trades,
            TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
        );
        SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }
}

//+------------------------------------------------------------------+
//| Send performance summary                                          |
//+------------------------------------------------------------------+
void SendPerformanceSummary()
{
    if(Enable_Telegram && total_trades > 0)
    {
        string msg = BuildPerformanceSummary(total_trades, winning_trades, total_profit, max_drawdown, AccountCurrency());
        SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }
}
