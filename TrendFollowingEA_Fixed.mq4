//+------------------------------------------------------------------+
//|                               TrendFollowingEA_Fixed_improved.mq4 |
//|                   Enhanced trend-following expert advisor        |
//|                                                                  |
//|  This refactored EA builds upon the original TrendFollowingEA    |
//|  with improved risk management, messaging, and clearer structure.|
//|  It enforces an intraday cap on both total trades and losing     |
//|  trades, automatically sends notifications via Telegram when     |
//|  trades are opened or closed, and remains configurable through   |
//|  external parameters.  Use this file as a template for your own  |
//|  trading experiments.                                            |
//|                                                                  |
//|  Author: ChatGPT (refactoring suggestion)                        |
//|  Date: 2025-08-07                                                |
//+------------------------------------------------------------------+

#property strict

#include <Trade\\AccountInfo.mqh>
#include "TelegramAPI_improved.mqh"

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

extern string    Settings_2              = "=== ENTRY & EXIT SETTINGS ===";
extern int       StopLoss_Pips           = 30;         // Fixed stop-loss in pips
extern double    Risk_Percent            = 1.0;        // Risk per trade (% of balance)
extern int       Max_Concurrent_Trades   = 1;          // Maximum positions open at once
extern bool      Enable_Breakeven        = true;       // Move SL to breakeven after 1×SL gain
extern double    Breakeven_Ratio         = 1.0;        // Profit-to-SL ratio to trigger BE move
extern bool      Enable_Trailing         = false;      // Enable trailing stops
extern int       Trailing_Start_Pips     = 20;         // Pips profit to start trailing
extern int       Trailing_Step_Pips      = 10;         // Trailing step in pips

extern string    Settings_3              = "=== RISK MANAGEMENT ===";
extern double    Daily_Loss_Limit_Pct    = 5.0;        // Stop trading after daily drawdown (%)
extern int       Max_Daily_Trades        = 5;          // Maximum trades per day
extern int       Max_Daily_Loss_Trades   = 3;          // Maximum losing trades per day
extern int       Max_Consecutive_Losses  = 3;          // Consecutive losses before pausing
extern string    Intraday_Close_Time     = "22:00";    // Time to close all positions

extern string    Settings_4              = "=== TELEGRAM SETTINGS ===";
extern string    Telegram_Bot_Token      = "YOUR_BOT_TOKEN_HERE";
extern string    Telegram_Chat_ID        = "YOUR_CHAT_ID_HERE";
extern bool      Enable_Telegram         = true;

extern string    Settings_5              = "=== MAGIC NUMBER ===";
extern int       Magic_Number            = 12345;

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
double   daily_start_balance = 0.0;
datetime last_bar_time       = 0;
datetime daily_reset_time    = 0;
bool     trading_allowed     = true;
int      daily_trade_count   = 0;
int      consecutive_losses  = 0;
int      daily_loss_trades   = 0;
string   ea_name             = "TrendFollowingEA_Improved";

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
    daily_start_balance = AccountBalance();
    daily_reset_time    = TimeCurrent();
    daily_trade_count   = 0;
    daily_loss_trades   = 0;
    consecutive_losses  = 0;
    trading_allowed     = true;

    // Notify user that the EA has started
    if(Enable_Telegram)
    {
        string msg = BuildEAStatusMessage(ea_name, Symbol(), (double)AccountBalance(), AccountCurrency(), (double)Risk_Percent, "Started");
        SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }

    Print(ea_name, " initialized successfully on ", Symbol());
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(Enable_Telegram)
    {
        string msg = BuildEAStatusMessage(ea_name, Symbol(), (double)AccountBalance(), AccountCurrency(), (double)Risk_Percent, "Stopped");
        SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
    }
    Print(ea_name, " deinitialization; reason ", reason);
}

//+------------------------------------------------------------------+
//| Main tick handler                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
    // Ensure sufficient bars for indicators
    if(Bars < TrendEMA_Period + 10)
        return;

    // Only process once per bar
    if(Time[0] == last_bar_time)
        return;
    last_bar_time = Time[0];

    // Reset counters on new day
    if(TimeDay(TimeCurrent()) != TimeDay(daily_reset_time))
    {
        daily_start_balance = AccountBalance();
        daily_reset_time    = TimeCurrent();
        daily_trade_count   = 0;
        daily_loss_trades   = 0;
        consecutive_losses  = 0;
        trading_allowed     = true;
    }

    // Check daily loss limit
    if(!CheckDailyLossLimit())
    {
        if(trading_allowed)
        {
            CloseAllPositions();
            trading_allowed = false;
            Print("Daily loss limit reached; trading disabled");

            if(Enable_Telegram)
            {
                double current_loss_pct = (daily_start_balance - AccountBalance()) / daily_start_balance * 100.0;
                string msg = BuildDailyLimitMessage((double)current_loss_pct, (double)Daily_Loss_Limit_Pct);
                SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
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

    // Manage active orders
    ManageExistingPositions();

    // Attempt to open new trades if conditions permit
    if(trading_allowed && CountOpenPositions() < Max_Concurrent_Trades && CanOpenNewTrade())
    {
        CheckForTradeEntry();
    }
}

//+------------------------------------------------------------------+
//| Validate input parameters                                         |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(TrendEMA_Period <= 0 || FastEMA_Period <= 0 || RSI_Period <= 0)
    {
        Alert("Indicator periods must be positive");
        return(false);
    }
    if(StopLoss_Pips <= 0)
    {
        Alert("StopLoss_Pips must be positive");
        return(false);
    }
    if(Risk_Percent <= 0 || Risk_Percent > 10)
    {
        Alert("Risk_Percent must be in (0,10]");
        return(false);
    }
    if(RSI_Long_Threshold <= 50 || RSI_Short_Threshold >= 50)
    {
        Alert("RSI thresholds must straddle 50");
        return(false);
    }
    if(Use_ADX_Filter && (ADX_Period <= 0 || ADX_Threshold < 0 || ADX_Threshold > 50))
    {
        Alert("Invalid ADX parameters");
        return(false);
    }
    return(true);
}

//+------------------------------------------------------------------+
//| Determine if a new trade can be opened                            |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
    if(daily_trade_count >= Max_Daily_Trades)
        return(false);
    if(consecutive_losses >= Max_Consecutive_Losses)
        return(false);
    if(daily_loss_trades >= Max_Daily_Loss_Trades)
        return(false);
    return(true);
}

//+------------------------------------------------------------------+
//| Evaluate entry conditions and open trade                          |
//+------------------------------------------------------------------+
void CheckForTradeEntry()
{
    // Indicator values
    double trend_ema_current  = iMA(NULL,0,TrendEMA_Period,0,MODE_EMA,PRICE_CLOSE,1);
    double trend_ema_prev     = iMA(NULL,0,TrendEMA_Period,0,MODE_EMA,PRICE_CLOSE,2);
    double fast_ema_current   = iMA(NULL,0,FastEMA_Period,0,MODE_EMA,PRICE_CLOSE,1);
    double fast_ema_prev      = iMA(NULL,0,FastEMA_Period,0,MODE_EMA,PRICE_CLOSE,2);
    double rsi_current        = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,1);

    double macd_main = 0;
    if(Use_MACD_Filter)
        macd_main = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);

    bool adx_ok = true;
    if(Use_ADX_Filter)
    {
        double adx_val = iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MAIN,1);
        adx_ok = (adx_val >= ADX_Threshold);
    }

    bool session_ok = (!Use_Session_Filter || IsWithinTradingSession());

    double close_price = Close[1];
    bool ema_cross_up   = (fast_ema_current > trend_ema_current && fast_ema_prev <= trend_ema_prev);
    bool ema_cross_down = (fast_ema_current < trend_ema_current && fast_ema_prev >= trend_ema_prev);
    bool price_confirms_long  = (close_price > trend_ema_current && close_price > fast_ema_current);
    bool price_confirms_short = (close_price < trend_ema_current && close_price < fast_ema_current);

    // Long entry
    if(price_confirms_long && ema_cross_up && rsi_current > RSI_Long_Threshold && (!Use_MACD_Filter || macd_main > 0) && adx_ok && session_ok)
    {
        OpenTrade(OP_BUY);
    }
    // Short entry
    if(price_confirms_short && ema_cross_down && rsi_current < RSI_Short_Threshold && (!Use_MACD_Filter || macd_main < 0) && adx_ok && session_ok)
    {
        OpenTrade(OP_SELL);
    }
}

//+------------------------------------------------------------------+
//| Check session boundaries                                          |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
{
    if(!Use_Session_Filter) return(true);
    int hh = TimeHour(TimeCurrent());
    int mm = TimeMinute(TimeCurrent());
    int curr = hh*60 + mm;
    int start = StringToInteger(StringSubstr(Session_Start_Time,0,2))*60 + StringToInteger(StringSubstr(Session_Start_Time,3,2));
    int end   = StringToInteger(StringSubstr(Session_End_Time,0,2))*60 + StringToInteger(StringSubstr(Session_End_Time,3,2));
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
    if(direction == OP_BUY)
    {
        sl = entry_price - StopLoss_Pips * Point * 10;
        tp = entry_price + (StopLoss_Pips * 3) * Point * 10;
    }
    else
    {
        sl = entry_price + StopLoss_Pips * Point * 10;
        tp = entry_price - (StopLoss_Pips * 3) * Point * 10;
    }
    sl = NormalizeDouble(sl, Digits);
    tp = NormalizeDouble(tp, Digits);
    string dir_str = (direction == OP_BUY) ? "BUY" : "SELL";
    string comment = StringFormat("%s_%s", ea_name, dir_str);
    int ticket = OrderSend(Symbol(), direction, lot, entry_price, 3, sl, tp, comment, Magic_Number, 0, clrNONE);
    if(ticket > 0)
    {
        daily_trade_count++;
        Print("Opened ", dir_str, " ", lot, " lots at ", entry_price);

        if(Enable_Telegram)
        {
            string msg = BuildTradeOpenedMessage(Symbol(), dir_str, (double)entry_price, (double)sl, (double)tp, (double)lot, (double)Risk_Percent);
            SendTelegramMessage(Telegram_Bot_Token, Telegram_Chat_ID, msg);
        }
    }
    else
    {
        Print("OrderSend failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculates trade lot size                                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance    = AccountBalance();
    double risk_amt   = balance * Risk_Percent / 100.0;
    double pip_value  = MarketInfo(Symbol(), MODE_TICKVALUE);
    if(Digits == 5 || Digits == 3)
        pip_value *= 10;
    double lot = risk_amt / (StopLoss_Pips * pip_value);
    double step = MarketInfo(Symbol(), MODE_LOTSTEP);
    lot = MathFloor(lot / step) * step;
    double minlot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxlot = MarketInfo(Symbol(), MODE_MAXLOT);
    if(lot < minlot) lot = minlot;
    if(lot > maxlot) lot = maxlot;
    return(lot);
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
        if(Enable_Breakeven && profit_pips >= sl_dist_pips * Breakeven_Ratio)
            MoveToBreakeven(OrderTicket(), OrderType(), OrderOpenPrice());
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
    if(sl_price == 0) return(0);
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
            Print("Moved order ", ticket, " to breakeven");
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
            if(!ok) Print("Trailing modification failed: ", GetLastError());
        }
    }
    else
    {
        new_sl = curr_price + Trailing_Step_Pips * Point * 10;
        if(new_sl < OrderStopLoss() - Point)
        {
            new_sl = NormalizeDouble(new_sl, Digits);
            bool ok = OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue);
            if(!ok) Print("Trailing modification failed: ", GetLastError());
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
            // Update loss counters
            if(OrderProfit() < 0)
            {
                consecutive_losses++;
                daily_loss_trades++;
            }
            else
            {
                consecutive_losses = 0;
            }
            // Notify via Telegram
            if(Enable_Telegram)
            {
                double pips = CalculateProfitPips(OrderType(), OrderOpenPrice(), close_price);
                bool win = (OrderProfit() > 0);
                string msg = BuildTradeClosedMessage(Symbol(), (double)close_price, (double)pips, (double)OrderProfit(), AccountCurrency(), win);
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
    return(count);
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
