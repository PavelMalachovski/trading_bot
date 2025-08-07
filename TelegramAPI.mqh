//+------------------------------------------------------------------+
//|                                           TelegramAPI_Refactored.mqh |
//|                   Enhanced Telegram integration for MT4 EAs       |
//|                                                                  |
//|  This module provides a robust Telegram integration for MT4      |
//|  Expert Advisors with improved error handling, retry logic,      |
//|  message queuing, and comprehensive logging.                     |
//|                                                                  |
//|  Features:                                                       |
//|  - Configurable retry attempts with exponential backoff          |
//|  - Message queuing for offline scenarios                        |
//|  - Enhanced error handling and logging                          |
//|  - Support for HTML and Markdown formatting                     |
//|  - Silent notification options                                   |
//|  - Connection timeout handling                                   |
//|                                                                  |
//|  Author: Refactored version                                      |
//|  Date: 2025-01-27                                                |
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
int  InternetSetOptionW(int, int, int, int);
#import

//--- Constants for WinInet
#define INTERNET_OPEN_TYPE_PRECONFIG 0
#define INTERNET_FLAG_SECURE 0x00800000
#define INTERNET_OPTION_CONNECT_TIMEOUT 2
#define INTERNET_OPTION_SEND_TIMEOUT 5
#define INTERNET_OPTION_RECEIVE_TIMEOUT 6

//--- Telegram API constants
#define TELEGRAM_API_HOST "api.telegram.org"
#define TELEGRAM_API_PORT 443
#define TELEGRAM_TIMEOUT 10000  // 10 seconds
#define MAX_RETRY_ATTEMPTS 3
#define RETRY_DELAY_BASE 1000   // 1 second base delay

//--- Message queue structure
struct TelegramMessage
{
    string bot_token;
    string chat_id;
    string message;
    string parse_mode;
    bool disable_notification;
    datetime timestamp;
};

//--- Global variables
TelegramMessage message_queue[];
int queue_size = 0;
bool telegram_enabled = true;
int last_error_code = 0;
string last_error_message = "";

//+------------------------------------------------------------------+
//| Encodes a string for HTTP transmission with improved handling     |
//+------------------------------------------------------------------+
string UrlEncode(const string str)
{
    if(StringLen(str) == 0) return "";

    string encoded = "";
    for(int i = 0; i < StringLen(str); i++)
    {
        int c = StringGetCharacter(str, i);

        // Safe characters: A-Z, a-z, 0-9, hyphen, underscore, period, tilde
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
//| Validates Telegram credentials                                    |
//+------------------------------------------------------------------+
bool ValidateTelegramCredentials(const string bot_token, const string chat_id)
{
    if(StringTrim(bot_token) == "" || StringTrim(chat_id) == "")
    {
        last_error_message = "Telegram credentials are not configured";
        last_error_code = 1001;
        return false;
    }

    // Basic format validation
    if(StringLen(bot_token) < 10 || StringLen(chat_id) < 5)
    {
        last_error_message = "Invalid Telegram credentials format";
        last_error_code = 1002;
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Sets connection timeout for WinInet handles                      |
//+------------------------------------------------------------------+
bool SetConnectionTimeout(int hInternet)
{
    if(hInternet == 0) return false;

    int timeout = TELEGRAM_TIMEOUT;
    bool result = true;

    result &= (InternetSetOptionW(hInternet, INTERNET_OPTION_CONNECT_TIMEOUT, timeout, 0) != 0);
    result &= (InternetSetOptionW(hInternet, INTERNET_OPTION_SEND_TIMEOUT, timeout, 0) != 0);
    result &= (InternetSetOptionW(hInternet, INTERNET_OPTION_RECEIVE_TIMEOUT, timeout, 0) != 0);

    return result;
}

//+------------------------------------------------------------------+
//| Sends a message to Telegram with retry logic and error handling  |
//+------------------------------------------------------------------+
bool SendTelegramMessage(
    const string bot_token,
    const string chat_id,
    const string message,
    const string parse_mode = "HTML",
    const bool disable_notification = false)
{
    // Validate inputs
    if(!ValidateTelegramCredentials(bot_token, chat_id))
    {
        Print("[Telegram] ", last_error_message);
        return false;
    }

    if(StringLen(message) == 0)
    {
        last_error_message = "Message cannot be empty";
        last_error_code = 1003;
        Print("[Telegram] ", last_error_message);
        return false;
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
    string host = TELEGRAM_API_HOST;
    string path = StringFormat("/bot%s/sendMessage", bot_token);

    // Retry logic with exponential backoff
    for(int attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++)
    {
        if(SendTelegramRequest(host, path, post_array))
        {
            last_error_code = 0;
            last_error_message = "";
            return true;
        }

        // If not the last attempt, wait before retrying
        if(attempt < MAX_RETRY_ATTEMPTS)
        {
            int delay = RETRY_DELAY_BASE * attempt; // Exponential backoff
            Sleep(delay);
            Print("[Telegram] Retry attempt ", attempt + 1, " of ", MAX_RETRY_ATTEMPTS);
        }
    }

    // If all attempts failed, queue the message for later
    QueueMessage(bot_token, chat_id, message, parse_mode, disable_notification);
    return false;
}

//+------------------------------------------------------------------+
//| Performs the actual HTTP request to Telegram API                 |
//+------------------------------------------------------------------+
bool SendTelegramRequest(const string host, const string path, const uchar &post_array[])
{
    int hInternet = 0, hConnection = 0, hRequest = 0;
    bool success = false;

    // Open WinInet session
    hInternet = InternetOpenW("MT4 Telegram Client", INTERNET_OPEN_TYPE_PRECONFIG, "", "", 0);
    if(hInternet == 0)
    {
        last_error_message = "InternetOpenW failed";
        last_error_code = 2001;
        return false;
    }

    // Set connection timeouts
    if(!SetConnectionTimeout(hInternet))
    {
        Print("[Telegram] Warning: Failed to set connection timeouts");
    }

    // Establish HTTPS connection
    hConnection = InternetConnectW(hInternet, host, TELEGRAM_API_PORT, "", "", 3, 0, 0);
    if(hConnection == 0)
    {
        last_error_message = "InternetConnectW failed";
        last_error_code = 2002;
        InternetCloseHandle(hInternet);
        return false;
    }

    // Prepare HTTP POST request
    hRequest = HttpOpenRequestW(hConnection, "POST", path, "HTTP/1.1", "", "", INTERNET_FLAG_SECURE, 0);
    if(hRequest == 0)
    {
        last_error_message = "HttpOpenRequestW failed";
        last_error_code = 2003;
        InternetCloseHandle(hConnection);
        InternetCloseHandle(hInternet);
        return false;
    }

    // Send the request
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    success = HttpSendRequestW(hRequest, headers, StringLen(headers), post_array, ArraySize(post_array));

    if(!success)
    {
        last_error_code = GetLastError();
        last_error_message = "HttpSendRequestW failed with error: " + IntegerToString(last_error_code);
    }

    // Clean up handles
    if(hRequest != 0) InternetCloseHandle(hRequest);
    if(hConnection != 0) InternetCloseHandle(hConnection);
    if(hInternet != 0) InternetCloseHandle(hInternet);

    return success;
}

//+------------------------------------------------------------------+
//| Queues a message for later sending when connection is restored   |
//+------------------------------------------------------------------+
void QueueMessage(
    const string bot_token,
    const string chat_id,
    const string message,
    const string parse_mode = "HTML",
    const bool disable_notification = false)
{
    if(queue_size >= 50) // Limit queue size
    {
        Print("[Telegram] Message queue full, dropping oldest message");
        // Remove oldest message
        for(int i = 0; i < queue_size - 1; i++)
        {
            message_queue[i] = message_queue[i + 1];
        }
        queue_size--;
    }

    // Add new message to queue
    message_queue[queue_size].bot_token = bot_token;
    message_queue[queue_size].chat_id = chat_id;
    message_queue[queue_size].message = message;
    message_queue[queue_size].parse_mode = parse_mode;
    message_queue[queue_size].disable_notification = disable_notification;
    message_queue[queue_size].timestamp = TimeCurrent();
    queue_size++;

    Print("[Telegram] Message queued. Queue size: ", queue_size);
}

//+------------------------------------------------------------------+
//| Attempts to send all queued messages                             |
//+------------------------------------------------------------------+
void ProcessMessageQueue()
{
    if(queue_size == 0) return;

    Print("[Telegram] Processing message queue (", queue_size, " messages)");

    for(int i = queue_size - 1; i >= 0; i--)
    {
        if(SendTelegramMessage(
            message_queue[i].bot_token,
            message_queue[i].chat_id,
            message_queue[i].message,
            message_queue[i].parse_mode,
            message_queue[i].disable_notification))
        {
            // Remove sent message from queue
            for(int j = i; j < queue_size - 1; j++)
            {
                message_queue[j] = message_queue[j + 1];
            }
            queue_size--;
        }
    }

    if(queue_size > 0)
    {
        Print("[Telegram] ", queue_size, " messages still in queue");
    }
}

//+------------------------------------------------------------------+
//| Gets the last error information                                  |
//+------------------------------------------------------------------+
void GetLastTelegramError(int &error_code, string &error_message)
{
    error_code = last_error_code;
    error_message = last_error_message;
}

//+------------------------------------------------------------------+
//| Enables or disables Telegram functionality                        |
//+------------------------------------------------------------------+
void SetTelegramEnabled(const bool enabled)
{
    telegram_enabled = enabled;
    if(!enabled)
    {
        Print("[Telegram] Telegram notifications disabled");
    }
}

//+------------------------------------------------------------------+
//| Gets the current queue size                                      |
//+------------------------------------------------------------------+
int GetMessageQueueSize()
{
    return queue_size;
}

//+------------------------------------------------------------------+
//| Clears the message queue                                         |
//+------------------------------------------------------------------+
void ClearMessageQueue()
{
    queue_size = 0;
    Print("[Telegram] Message queue cleared");
}

//+------------------------------------------------------------------+
//| Helper to format trade open notification with enhanced styling   |
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
    string color_tag = (direction == "BUY") ? "<b>" : "<b>";
    string color_end = "</b>";

    return(StringFormat(
        "%s <b>Trade Opened</b>\n"
        "📊 %s%s %s%s\n"
        "💱 Entry: <code>%.5f</code>\n"
        "🛑 SL: <code>%.5f</code>\n"
        "🎯 TP: <code>%.5f</code>\n"
        "💰 Size: <code>%.2f</code> lots\n"
        "📊 Risk: <code>%.1f%%</code>\n"
        "⏰ %s",
        emoji, color_tag, symbol, direction, color_end,
        entry_price, stop_loss, take_profit,
        lot_size, risk_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format trade close notification with enhanced styling  |
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
    string color_tag = is_winner ? "<b>" : "<b>";
    string color_end = "</b>";

    return(StringFormat(
        "%s <b>Trade Closed - %s</b>\n"
        "📊 %s%s%s\n"
        "💱 Close: <code>%.5f</code>\n"
        "📈 Pips: <code>%.1f</code>\n"
        "💰 P/L: <code>%.2f %s</code>\n"
        "⏰ %s",
        emoji, color_tag, result, color_end,
        symbol,
        close_price, profit_pips, profit_amount, currency,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format EA status notification with enhanced styling    |
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
    string color_tag = (status == "Started") ? "<b>" : "<b>";
    string color_end = "</b>";

    return(StringFormat(
        "%s <b>%s %s</b>\n"
        "📊 Symbol: <code>%s</code>\n"
        "💰 Balance: <code>%.2f %s</code>\n"
        "⚙️ Risk: <code>%.1f%%</code>\n"
        "⏰ %s",
        emoji, color_tag, ea_name, status, color_end,
        symbol, balance, currency,
        risk_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format daily limit notification with enhanced styling  |
//+------------------------------------------------------------------+
string BuildDailyLimitMessage(const double loss_pct, const double limit_pct)
{
    return(StringFormat(
        "⚠️ <b>Daily Loss Limit Reached</b>\n"
        "📉 Current Loss: <code>%.2f%%</code>\n"
        "🚫 Limit: <code>%.2f%%</code>\n"
        "🕐 Trading disabled until tomorrow\n"
        "⏰ %s",
        loss_pct, limit_pct,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format error notification                              |
//+------------------------------------------------------------------+
string BuildErrorMessage(const string error_type, const string details)
{
    return(StringFormat(
        "🚨 <b>Error: %s</b>\n"
        "📝 Details: %s\n"
        "⏰ %s",
        error_type, details,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}

//+------------------------------------------------------------------+
//| Helper to format performance summary                              |
//+------------------------------------------------------------------+
string BuildPerformanceSummary(
    const int total_trades,
    const int winning_trades,
    const double total_profit,
    const double max_drawdown,
    const string currency)
{
    double win_rate = (total_trades > 0) ? (double)winning_trades / total_trades * 100.0 : 0.0;

    return(StringFormat(
        "📊 <b>Performance Summary</b>\n"
        "📈 Total Trades: <code>%d</code>\n"
        "✅ Winning Trades: <code>%d</code>\n"
        "📊 Win Rate: <code>%.1f%%</code>\n"
        "💰 Total P/L: <code>%.2f %s</code>\n"
        "📉 Max Drawdown: <code>%.2f%%</code>\n"
        "⏰ %s",
        total_trades, winning_trades, win_rate,
        total_profit, currency, max_drawdown,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
    ));
}
