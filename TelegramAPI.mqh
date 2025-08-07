//+------------------------------------------------------------------+
//|                                                  TelegramAPI.mqh |
//|                       Copyright 2024, Professional Trading Bot |
//|                                             https://example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Professional Trading Bot"
#property link      "https://example.com"
#property strict

#import "wininet.dll"
int InternetOpenW(string, int, string, string, int);
int InternetConnectW(int, string, int, string, string, int, int, int);
int HttpOpenRequestW(int, string, string, string, string, string, int, int);
bool HttpSendRequestW(int, string, int, uchar &arr[], int);
bool InternetReadFile(int, uchar &arr[], int, int &OneInt[]);
bool InternetCloseHandle(int);
#import

//+------------------------------------------------------------------+
//| Send HTTP POST request to Telegram API                           |
//+------------------------------------------------------------------+
bool SendTelegramNotification(string bot_token, string chat_id, string message)
{
    if(bot_token == "YOUR_BOT_TOKEN_HERE" || chat_id == "YOUR_CHAT_ID_HERE")
    {
        Print("Telegram credentials not configured");
        return false;
    }

    // URL encode the message
    string encoded_message = UrlEncode(message);

    // Prepare POST data
    string post_data = StringFormat("chat_id=%s&text=%s&parse_mode=HTML", chat_id, encoded_message);
    uchar post_array[];
    StringToCharArray(post_data, post_array, 0, StringLen(post_data));

    // API endpoint
    string host = "api.telegram.org";
    string path = StringFormat("/bot%s/sendMessage", bot_token);

    // Open internet connection
    int internet = InternetOpenW("TelegramBot/1.0", 1, "", "", 0);
    if(internet == 0)
    {
        Print("Failed to open internet connection");
        return false;
    }

    // Connect to Telegram API
    int connect = InternetConnectW(internet, host, 443, "", "", 3, 0, 0);
    if(connect == 0)
    {
        InternetCloseHandle(internet);
        Print("Failed to connect to Telegram API");
        return false;
    }

    // Open HTTP request
    int request = HttpOpenRequestW(connect, "POST", path, "HTTP/1.1", "", "", 0x00800000, 0);
    if(request == 0)
    {
        InternetCloseHandle(connect);
        InternetCloseHandle(internet);
        Print("Failed to open HTTP request");
        return false;
    }

    // Set headers
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

    // Send request
    bool sent = HttpSendRequestW(request, headers, StringLen(headers), post_array, ArraySize(post_array));

    // Clean up
    InternetCloseHandle(request);
    InternetCloseHandle(connect);
    InternetCloseHandle(internet);

    if(sent)
    {
        Print("Telegram notification sent successfully");
        return true;
    }
    else
    {
        Print("Failed to send Telegram notification");
        return false;
    }
}

//+------------------------------------------------------------------+
//| URL encode string for HTTP requests                              |
//+------------------------------------------------------------------+
string UrlEncode(string str)
{
    string encoded = "";
    for(int i = 0; i < StringLen(str); i++)
    {
        int char_code = StringGetCharacter(str, i);

        // Alphanumeric characters and some special chars don't need encoding
        if((char_code >= 48 && char_code <= 57) ||   // 0-9
           (char_code >= 65 && char_code <= 90) ||   // A-Z
           (char_code >= 97 && char_code <= 122) ||  // a-z
           char_code == 45 || char_code == 95 ||     // - and _
           char_code == 46 || char_code == 126)      // . and ~
        {
            encoded += CharToString(char_code);
        }
        else if(char_code == 32) // Space
        {
            encoded += "+";
        }
        else
        {
            encoded += StringFormat("%%%02X", char_code);
        }
    }
    return encoded;
}

//+------------------------------------------------------------------+
//| Format trade opened message                                      |
//+------------------------------------------------------------------+
string FormatTradeOpenedMessage(string symbol, string direction, double entry_price,
                              double stop_loss, double take_profit, double lot_size, double risk_pct)
{
    string emoji = (direction == "BUY") ? "📈" : "📉";

    return StringFormat(
        "<b>%s Trade Opened</b>\n"
        "📊 <b>%s %s</b>\n"
        "💱 Entry: <code>%.5f</code>\n"
        "🛑 SL: <code>%.5f</code>\n"
        "🎯 TP: <code>%.5f</code>\n"
        "💰 Size: <code>%.2f</code> lots\n"
        "📊 Risk: <code>%.1f%%</code>\n"
        "⏰ %s",
        emoji, symbol, direction, entry_price, stop_loss, take_profit,
        lot_size, risk_pct, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    );
}

//+------------------------------------------------------------------+
//| Format trade closed message                                      |
//+------------------------------------------------------------------+
string FormatTradeClosedMessage(string symbol, double close_price, double profit_pips,
                               double profit_amount, string currency, bool is_winner)
{
    string emoji = is_winner ? "✅" : "❌";
    string result = is_winner ? "WIN" : "LOSS";

    return StringFormat(
        "<b>%s Trade Closed - %s</b>\n"
        "📊 <b>%s</b>\n"
        "💱 Close: <code>%.5f</code>\n"
        "📈 Pips: <code>%.1f</code>\n"
        "💰 P/L: <code>%.2f %s</code>\n"
        "⏰ %s",
        emoji, result, symbol, close_price, profit_pips,
        profit_amount, currency, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    );
}

//+------------------------------------------------------------------+
//| Format EA status message                                         |
//+------------------------------------------------------------------+
string FormatEAStatusMessage(string ea_name, string symbol, double balance,
                            string currency, double risk_pct, string status)
{
    string emoji = (status == "Started") ? "🤖" : "🛑";

    return StringFormat(
        "<b>%s %s %s</b>\n"
        "📊 Symbol: <code>%s</code>\n"
        "💰 Balance: <code>%.2f %s</code>\n"
        "⚙️ Risk: <code>%.1f%%</code>\n"
        "⏰ %s",
        emoji, ea_name, status, symbol, balance, currency,
        risk_pct, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    );
}

//+------------------------------------------------------------------+
//| Format daily limit warning message                               |
//+------------------------------------------------------------------+
string FormatDailyLimitMessage(double loss_pct, double limit_pct)
{
    return StringFormat(
        "<b>⚠️ Daily Loss Limit Reached</b>\n"
        "📉 Current Loss: <code>%.2f%%</code>\n"
        "🚫 Limit: <code>%.2f%%</code>\n"
        "🕐 Trading disabled until tomorrow\n"
        "⏰ %s",
        loss_pct, limit_pct, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    );
}
