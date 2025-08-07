//+------------------------------------------------------------------+
//|                                             TelegramAPI_improved.mqh |
//|                   Enhanced Telegram integration for MT4 EAs       |
//|                                                                  |
//|  This module refactors the original TelegramAPI.mqh file used    |
//|  in the TrendFollowingEA. It adds error handling, configurable   |
//|  parameters for better security and flexibility, and a generic    |
//|  message sender capable of toggling Markdown/HTML formatting and |
//|  disabling notifications.                                        |
//|                                                                  |
//|  Author: ChatGPT (refactoring suggestion)                        |
//|  Date: 2025-08-07                                                |
//+------------------------------------------------------------------+

#property strict

//--- WinInet import declarations for HTTPS requests
#import "wininet.dll"
int  InternetOpenW(string, int, string, string, int);
int  InternetConnectW(int, string, int, string, string, int, int, int);
int  HttpOpenRequestW(int, string, string, string, string, string, int, int);
bool HttpSendRequestW(int, string, int, uchar &arr[], int);
bool InternetReadFile(int, uchar &arr[], int, int &OneInt[]);
bool InternetCloseHandle(int);
#import

//+------------------------------------------------------------------+
//| Encodes a string for HTTP transmission                           |
//+------------------------------------------------------------------+
string UrlEncode(const string str)
{
    string encoded = "";
    for(int i = 0; i < StringLen(str); i++)
    {
        int c = StringGetCharacter(str, i);
        // A–Z, a–z, 0–9, hyphen, underscore, period and tilde are safe
        bool safe = ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) ||
                     (c >= 97 && c <= 122) || c == 45 || c == 95 ||
                     c == 46 || c == 126);
        if(safe)
            encoded += CharToString(c);
        else if(c == 32)
            encoded += "+";
        else
            encoded += StringFormat("%%%02X", c);
    }
    return encoded;
}

//+------------------------------------------------------------------+
//| Sends an arbitrary message to Telegram using the provided        |
//| bot token and chat ID. Supports optional HTML/Markdown mode      |
//| selection and silent notifications. Returns true if the request  |
//| was dispatched successfully; note that a successful dispatch     |
//| does not guarantee delivery, only that the request was accepted  |
//| by WinInet.                                                     |
//+------------------------------------------------------------------+
bool SendTelegramMessage(
    const string bot_token,
    const string chat_id,
    const string message,
    const string parse_mode = "HTML",
    const bool disable_notification = false)
{
    if(StringTrim(bot_token) == "" || StringTrim(chat_id) == "")
    {
        Print("Telegram credentials are not configured");
        return(false);
    }

    // URL-encode the message and build POST payload
    string encoded = UrlEncode(message);
    string post_data = StringFormat(
        "chat_id=%s&text=%s&parse_mode=%s&disable_notification=%s",
        chat_id, encoded, parse_mode,
        disable_notification ? "true" : "false"
    );

    uchar post_array[];
    StringToCharArray(post_data, post_array, 0, StringLen(post_data));

    // API host and path
    string host = "api.telegram.org";
    string path = StringFormat("/bot%s/sendMessage", bot_token);

    // Open WinInet session
    int hInternet = InternetOpenW("MT4 Telegram Client", 1, "", "", 0);
    if(hInternet == 0)
    {
        Print("[Telegram] InternetOpenW failed");
        return(false);
    }

    // Establish HTTPS connection
    int hConnection = InternetConnectW(hInternet, host, 443, "", "", 3, 0, 0);
    if(hConnection == 0)
    {
        Print("[Telegram] InternetConnectW failed");
        InternetCloseHandle(hInternet);
        return(false);
    }

    // Prepare HTTP POST request
    int hRequest = HttpOpenRequestW(hConnection, "POST", path, "HTTP/1.1", "", "", 0x00800000, 0);
    if(hRequest == 0)
    {
        Print("[Telegram] HttpOpenRequestW failed");
        InternetCloseHandle(hConnection);
        InternetCloseHandle(hInternet);
        return(false);
    }

    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    bool sent = HttpSendRequestW(hRequest, headers, StringLen(headers), post_array, ArraySize(post_array));

    // Clean up handles
    InternetCloseHandle(hRequest);
    InternetCloseHandle(hConnection);
    InternetCloseHandle(hInternet);

    if(!sent)
    {
        Print("[Telegram] HttpSendRequestW failed");
    }

    return(sent);
}

//+------------------------------------------------------------------+
//| Helper to format trade open notification                         |
//+------------------------------------------------------------------+
string BuildTradeOpenedMessage(
    const string symbol,
    const string direction,
    const double entry_price,
    const double stop_loss,
    const double take_profit,
    const double lot_size,
    const double risk_pct)
{
    string emoji = (direction == "BUY") ? "📈" : "📉";
    return(StringFormat(
        " %s Trade Opened\n"
        "📊 %s %s\n"
        "💱 Entry: %.5f\n"
        "🛑 SL: %.5f\n"
        "🎯 TP: %.5f\n"
        "💰 Size: %.2f lots\n"
        "📊 Risk: %.1f%%\n"
        "⏰ %s",
        emoji, symbol, direction,
        entry_price, stop_loss, take_profit,
        lot_size, risk_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format trade close notification                        |
//+------------------------------------------------------------------+
string BuildTradeClosedMessage(
    const string symbol,
    const double close_price,
    const double profit_pips,
    const double profit_amount,
    const string currency,
    const bool is_winner)
{
    string emoji = is_winner ? "✅" : "❌";
    string result = is_winner ? "WIN" : "LOSS";
    return(StringFormat(
        " %s Trade Closed - %s\n"
        "📊 %s\n"
        "💱 Close: %.5f\n"
        "📈 Pips: %.1f\n"
        "💰 P/L: %.2f %s\n"
        "⏰ %s",
        emoji, result, symbol,
        close_price, profit_pips, profit_amount, currency,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format EA status notification                          |
//+------------------------------------------------------------------+
string BuildEAStatusMessage(
    const string ea_name,
    const string symbol,
    const double balance,
    const string currency,
    const double risk_pct,
    const string status)
{
    string emoji = (status == "Started") ? "🤖" : "🛑";
    return(StringFormat(
        " %s %s %s\n"
        "📊 Symbol: %s\n"
        "💰 Balance: %.2f %s\n"
        "⚙️ Risk: %.1f%%\n"
        "⏰ %s",
        emoji, ea_name, status,
        symbol, balance, currency,
        risk_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format daily limit notification                         |
//+------------------------------------------------------------------+
string BuildDailyLimitMessage(const double loss_pct, const double limit_pct)
{
    return(StringFormat(
        " ⚠️ Daily Loss Limit Reached\n"
        "📉 Current Loss: %.2f%%\n"
        "🚫 Limit: %.2f%%\n"
        "🕐 Trading disabled until tomorrow\n"
        "⏰ %s",
        loss_pct, limit_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}
