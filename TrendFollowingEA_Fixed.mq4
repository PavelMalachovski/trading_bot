//+------------------------------------------------------------------+
//|                                     TrendFollowingEA_Fixed.mq4 |
//|                       Copyright 2024, Professional Trading Bot |
//|                                             https://example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Professional Trading Bot"
#property link      "https://example.com"
#property version   "1.10"
#property strict

#include <stdlib.mqh>
#include "..\Include\TelegramAPI.mqh"

//+------------------------------------------------------------------+
//| External parameters - User configurable inputs                   |
//+------------------------------------------------------------------+
extern string    Settings_1            = "=== TREND FILTER SETTINGS ===";
extern int       TrendEMA_Period       = 200;        // Long-term trend EMA period
extern int       FastEMA_Period        = 21;         // Fast momentum EMA period
extern int       RSI_Period            = 14;         // RSI period
extern double    RSI_Long_Threshold    = 55.0;       // RSI threshold for long trades
extern double    RSI_Short_Threshold   = 45.0;       // RSI threshold for short trades
extern bool      Use_MACD_Filter       = true;       // Enable MACD histogram filter

extern string    Settings_1B           = "=== ENHANCED FILTERS ===";
extern bool      Use_ADX_Filter        = true;       // Enable ADX trend strength filter
extern int       ADX_Period            = 14;         // ADX period
extern double    ADX_Threshold         = 25.0;       // Minimum ADX for trend strength
extern bool      Use_Session_Filter    = true;       // Enable session time filter
extern string    Session_Start_Time    = "08:00";    // Trading session start time
extern string    Session_End_Time      = "20:00";    // Trading session end time

extern string    Settings_2            = "=== ENTRY & EXIT SETTINGS ===";
extern int       StopLoss_Pips         = 30;         // Stop loss in pips
extern double    Risk_Percent          = 1.0;        // Risk per trade as % of balance
extern int       Max_Concurrent_Trades = 1;          // Maximum concurrent positions
extern bool      Enable_Breakeven      = true;       // Move SL to breakeven after 1xSL profit
extern double    Breakeven_Ratio       = 1.0;        // Ratio of SL distance to trigger breakeven
extern bool      Enable_Trailing       = false;      // Enable trailing stop
extern int       Trailing_Start_Pips   = 20;         // Pips profit to start trailing
extern int       Trailing_Step_Pips    = 10;         // Trailing step in pips

extern string    Settings_3            = "=== RISK MANAGEMENT ===";
extern double    Daily_Loss_Limit_Pct  = 5.0;        // Daily loss limit as % of balance
extern int       Max_Daily_Trades      = 5;          // Maximum trades per day
extern int       Max_Consecutive_Losses = 5;         // Max consecutive losses before pause
extern string    Intraday_Close_Time   = "22:00";    // Time to close all positions (HH:MM)

extern string    Settings_4            = "=== TELEGRAM SETTINGS ===";
extern string    Telegram_Bot_Token    = "YOUR_BOT_TOKEN_HERE";     // Telegram bot token
extern string    Telegram_Chat_ID      = "YOUR_CHAT_ID_HERE";       // Telegram chat ID
extern bool      Enable_Telegram       = true;       // Enable Telegram notifications

extern string    Settings_5            = "=== MAGIC NUMBER ===";
extern int       Magic_Number          = 12345;      // Unique identifier for this EA

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double daily_start_balance = 0.0;
datetime last_bar_time = 0;
datetime daily_reset_time = 0;
bool trading_allowed = true;
int daily_trade_count = 0;
int consecutive_losses = 0;
string ea_name = "TrendFollowingEA_Fixed";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate input parameters
    if(!ValidateInputs())
    {
        Print("Invalid input parameters. EA will not trade.");
        return INIT_PARAMETERS_INCORRECT;
    }

    // Initialize daily balance tracking
    daily_start_balance = AccountBalance();
    daily_reset_time = TimeCurrent();

    // Send startup notification
    if(Enable_Telegram)
    {
        string msg = FormatEAStatusMessage(ea_name, Symbol(), (double)AccountBalance(), AccountCurrency(), (double)Risk_Percent, "Started");
        SendTelegramNotification(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }

    Print("TrendFollowingEA Fixed v1.10 initialized successfully on ", Symbol());
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(Enable_Telegram)
    {
        string msg = FormatEAStatusMessage(ea_name, Symbol(), (double)AccountBalance(), AccountCurrency(), (double)Risk_Percent, "Stopped");
        SendTelegramNotification(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }

    Print("TrendFollowingEA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function - Main trading logic                        |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if we have enough bars
    if(Bars < TrendEMA_Period + 10)
    {
        return;
    }

    // Check if new bar formed
    if(Time[0] == last_bar_time)
    {
        return;
    }
    last_bar_time = Time[0];

    // Reset daily counters if new day
    if(TimeDay(TimeCurrent()) != TimeDay(daily_reset_time))
    {
        daily_start_balance = AccountBalance();
        daily_reset_time = TimeCurrent();
        daily_trade_count = 0;
        trading_allowed = true;
    }

    // Check daily loss limit
    if(!CheckDailyLossLimit())
    {
        if(trading_allowed)
        {
            CloseAllPositions();
            trading_allowed = false;
            Print("Daily loss limit reached. Trading disabled for today.");

            if(Enable_Telegram)
            {
                double current_loss_pct = (daily_start_balance - AccountBalance()) / daily_start_balance * 100.0;
                string msg = FormatDailyLimitMessage((double)current_loss_pct, (double)Daily_Loss_Limit_Pct);
                SendTelegramNotification(Telegram_Bot_Token, Telegram_Chat_ID, msg);
            }
        }
        return;
    }

    // Check intraday close time
    if(IsIntradayCloseTime())
    {
        CloseAllPositions();
        return;
    }

    // Manage existing positions
    ManageExistingPositions();

    // Check for new trade opportunities
    if(trading_allowed && CountOpenPositions() < Max_Concurrent_Trades && CanOpenNewTrade())
    {
        CheckForTradeEntry();
    }
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(TrendEMA_Period <= 0 || FastEMA_Period <= 0 || RSI_Period <= 0)
    {
        Alert("Invalid indicator periods");
        return false;
    }

    if(StopLoss_Pips <= 0)
    {
        Alert("Stop loss must be positive");
        return false;
    }

    if(Risk_Percent <= 0 || Risk_Percent > 10)
    {
        Alert("Risk percent must be between 0 and 10");
        return false;
    }

    if(RSI_Long_Threshold <= 50 || RSI_Short_Threshold >= 50)
    {
        Alert("Invalid RSI thresholds");
        return false;
    }

    if(Use_ADX_Filter && (ADX_Period <= 0 || ADX_Threshold < 0 || ADX_Threshold > 50))
    {
        Alert("Invalid ADX parameters");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Enhanced trade entry conditions with multiple filters           |
//+------------------------------------------------------------------+
void CheckForTradeEntry()
{
    // Get indicator values
    double trend_ema_current = iMA(NULL, 0, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double fast_ema_current = iMA(NULL, 0, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double fast_ema_previous = iMA(NULL, 0, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
    double trend_ema_previous = iMA(NULL, 0, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
    double rsi_current = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, 1);

    double macd_main = 0;
    if(Use_MACD_Filter)
    {
        macd_main = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
    }

    // Enhanced filters
    bool adx_confirms = true;
    if(Use_ADX_Filter)
    {
        double adx_val = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
        adx_confirms = adx_val >= ADX_Threshold;
    }

    bool session_allowed = true;
    if(Use_Session_Filter)
    {
        session_allowed = IsWithinTradingSession();
    }

    double close_price = Close[1];

    // Enhanced EMA cross detection
    bool ema_cross_up = fast_ema_current > trend_ema_current && fast_ema_previous <= trend_ema_previous;
    bool ema_cross_down = fast_ema_current < trend_ema_current && fast_ema_previous >= trend_ema_previous;

    // Price confirmation
    bool price_confirms_long = close_price > trend_ema_current && close_price > fast_ema_current;
    bool price_confirms_short = close_price < trend_ema_current && close_price < fast_ema_current;

    // Long entry conditions
    if(price_confirms_long &&
       ema_cross_up &&
       rsi_current > RSI_Long_Threshold &&
       (!Use_MACD_Filter || macd_main > 0) &&
       adx_confirms &&
       session_allowed)
    {
        OpenTrade(OP_BUY);
    }

    // Short entry conditions
    if(price_confirms_short &&
       ema_cross_down &&
       rsi_current < RSI_Short_Threshold &&
       (!Use_MACD_Filter || macd_main < 0) &&
       adx_confirms &&
       session_allowed)
    {
        OpenTrade(OP_SELL);
    }
}

//+------------------------------------------------------------------+
//| Check if within allowed trading session                         |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
{
    if(!Use_Session_Filter) return true;

    int current_hour = TimeHour(TimeCurrent());
    int current_minute = TimeMinute(TimeCurrent());
    int current_minutes = current_hour * 60 + current_minute;

    // Parse session start time
    string start_hour_str = StringSubstr(Session_Start_Time, 0, 2);
    string start_minute_str = StringSubstr(Session_Start_Time, 3, 2);
    int start_minutes = StringToInteger(start_hour_str) * 60 + StringToInteger(start_minute_str);

    // Parse session end time
    string end_hour_str = StringSubstr(Session_End_Time, 0, 2);
    string end_minute_str = StringSubstr(Session_End_Time, 3, 2);
    int end_minutes = StringToInteger(end_hour_str) * 60 + StringToInteger(end_minute_str);

    return current_minutes >= start_minutes && current_minutes <= end_minutes;
}

//+------------------------------------------------------------------+
//| Enhanced trade eligibility check                                |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
    // Check daily trade limit
    if(daily_trade_count >= Max_Daily_Trades) return false;

    // Check consecutive losses
    if(consecutive_losses >= Max_Consecutive_Losses) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Open a new trade with proper risk management                     |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
    double lot_size = CalculateLotSize();
    if(lot_size <= 0)
    {
        Print("Invalid lot size calculated: ", lot_size);
        return;
    }

    double entry_price = (direction == OP_BUY) ? Ask : Bid;
    double stop_loss, take_profit;

    if(direction == OP_BUY)
    {
        stop_loss = entry_price - StopLoss_Pips * Point * 10;
        take_profit = entry_price + (StopLoss_Pips * 3) * Point * 10;
    }
    else
    {
        stop_loss = entry_price + StopLoss_Pips * Point * 10;
        take_profit = entry_price - (StopLoss_Pips * 3) * Point * 10;
    }

    // Normalize prices
    stop_loss = NormalizeDouble(stop_loss, Digits);
    take_profit = NormalizeDouble(take_profit, Digits);

    string direction_str = (direction == OP_BUY) ? "BUY" : "SELL";
    string comment = StringFormat("%s_%s", ea_name, direction_str);

    int ticket = OrderSend(Symbol(), direction, lot_size, entry_price, 3, stop_loss, take_profit, comment, Magic_Number, 0, clrNONE);

    if(ticket > 0)
    {
        daily_trade_count++;
        Print("Trade opened: ", direction_str, " ", lot_size, " lots at ", entry_price);

        if(Enable_Telegram)
        {
            string msg = FormatTradeOpenedMessage(Symbol(), direction_str, (double)entry_price, (double)stop_loss, (double)take_profit, (double)lot_size, (double)Risk_Percent);
            SendTelegramNotification(Telegram_Bot_Token, Telegram_Chat_ID, msg);
        }
    }
    else
    {
        Print("Failed to open trade. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountBalance();
    double risk_amount = balance * Risk_Percent / 100.0;
    double pip_value = MarketInfo(Symbol(), MODE_TICKVALUE);

    if(Digits == 5 || Digits == 3)
    {
        pip_value *= 10; // Adjust for 5-digit brokers
    }

    double lot_size = risk_amount / (StopLoss_Pips * pip_value);

    // Normalize to broker's lot step
    double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
    lot_size = MathFloor(lot_size / lot_step) * lot_step;

    // Check min/max lot sizes
    double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
    double max_lot = MarketInfo(Symbol(), MODE_MAXLOT);

    if(lot_size < min_lot) lot_size = min_lot;
    if(lot_size > max_lot) lot_size = max_lot;

    return lot_size;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Number) continue;

        double current_price = (OrderType() == OP_BUY) ? Bid : Ask;
        double profit_pips = CalculateProfitPips(OrderType(), OrderOpenPrice(), current_price);
        double sl_distance_pips = CalculateSLDistancePips(OrderType(), OrderOpenPrice(), OrderStopLoss());

        // Enhanced breakeven logic
        if(Enable_Breakeven && profit_pips >= sl_distance_pips * Breakeven_Ratio)
        {
            MoveToBreakeven(OrderTicket(), OrderType(), OrderOpenPrice());
        }

        // Enhanced trailing stop
        if(Enable_Trailing && profit_pips >= Trailing_Start_Pips)
        {
            TrailingStop(OrderTicket(), OrderType(), current_price);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate profit in pips                                        |
//+------------------------------------------------------------------+
double CalculateProfitPips(int order_type, double open_price, double current_price)
{
    double pip_factor = (Digits == 5 || Digits == 3) ? 10 : 1;

    if(order_type == OP_BUY)
        return (current_price - open_price) / Point / pip_factor;
    else
        return (open_price - current_price) / Point / pip_factor;
}

//+------------------------------------------------------------------+
//| Calculate stop loss distance in pips                           |
//+------------------------------------------------------------------+
double CalculateSLDistancePips(int order_type, double open_price, double sl_price)
{
    if(sl_price == 0) return 0;

    double pip_factor = (Digits == 5 || Digits == 3) ? 10 : 1;

    if(order_type == OP_BUY)
        return (open_price - sl_price) / Point / pip_factor;
    else
        return (sl_price - open_price) / Point / pip_factor;
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven                                      |
//+------------------------------------------------------------------+
void MoveToBreakeven(int ticket, int order_type, double open_price)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

    double new_sl = NormalizeDouble(open_price, Digits);

    // Check if SL is not already at breakeven
    if(MathAbs(OrderStopLoss() - new_sl) > Point)
    {
        bool result = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
        if(result)
        {
            Print("Moved to breakeven for ticket: ", ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Implement trailing stop                                          |
//+------------------------------------------------------------------+
void TrailingStop(int ticket, int order_type, double current_price)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

    double new_sl = 0;

    if(order_type == OP_BUY)
    {
        new_sl = current_price - Trailing_Step_Pips * Point * 10;
        if(new_sl > OrderStopLoss() + Point)
        {
            new_sl = NormalizeDouble(new_sl, Digits);
            bool modify_result = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
            if(!modify_result)
            {
                Print("Failed to modify BUY order. Error: ", GetLastError());
            }
        }
    }
    else if(order_type == OP_SELL)
    {
        new_sl = current_price + Trailing_Step_Pips * Point * 10;
        if(new_sl < OrderStopLoss() - Point)
        {
            new_sl = NormalizeDouble(new_sl, Digits);
            bool modify_result = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
            if(!modify_result)
            {
                Print("Failed to modify SELL order. Error: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if it's time for intraday position closure                 |
//+------------------------------------------------------------------+
bool IsIntradayCloseTime()
{
    string current_time = TimeToStr(TimeCurrent(), TIME_MINUTES);
    return StringFind(current_time, Intraday_Close_Time) >= 0;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Number) continue;

        double close_price = (OrderType() == OP_BUY) ? Bid : Ask;
        bool result = OrderClose(OrderTicket(), OrderLots(), close_price, 3, clrRed);

        if(result)
        {
            // Update consecutive losses counter
            if(OrderProfit() < 0)
            {
                consecutive_losses++;
            }
            else
            {
                consecutive_losses = 0;
            }

            if(Enable_Telegram)
            {
                double profit_pips = CalculateProfitPips(OrderType(), OrderOpenPrice(), close_price);
                bool is_winner = OrderProfit() > 0;
                string msg = FormatTradeClosedMessage(Symbol(), (double)close_price, (double)profit_pips, (double)OrderProfit(), AccountCurrency(), is_winner);
                SendTelegramNotification(Telegram_Bot_Token, Telegram_Chat_ID, msg);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic_Number)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
    double current_balance = AccountBalance();
    double daily_loss_pct = (daily_start_balance - current_balance) / daily_start_balance * 100.0;

    return daily_loss_pct < Daily_Loss_Limit_Pct;
}

//+------------------------------------------------------------------+
//| Handle trade close events for notifications                      |
//+------------------------------------------------------------------+
void OnTrade()
{
    // This function is called on trade events
    static int last_total = 0;
    int current_total = OrdersHistoryTotal();

    if(current_total > last_total)
    {
        last_total = current_total;
    }
}
