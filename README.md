# TrendFollowingEA - Professional MetaTrader 4 Expert Advisor

A production-ready MetaTrader 4 Expert Advisor that implements a sophisticated trend-following strategy with strict risk management and Telegram notifications.

## 🎯 Key Features

- **Trend Following Strategy**: Uses 200-period EMA for trend direction, 21-period EMA for momentum
- **Fixed Risk-to-Reward**: 1:3 ratio with automatic position sizing
- **Intraday Only**: Automatically closes all positions by 22:00 server time
- **Smart Entry Logic**: RSI confirmation + optional MACD filter
- **Advanced Risk Management**: 1% risk per trade, daily loss limits, breakeven protection
- **Telegram Integration**: Real-time trade notifications with formatted messages
- **High Win Rate Target**: Optimized for ≥60% win rate on major FX pairs

## 📋 Requirements

- MetaTrader 4 (build ≥ 1380)
- Demo or live trading account
- Telegram Bot (optional but recommended)
- Windows OS with WinInet.dll support

## 🚀 Quick Setup

### 1. Installation

1. Copy `TrendFollowingEA.mq4` and `TelegramAPI.mqh` to your MT4 `MQL4/Experts/` folder
2. Restart MetaTrader 4 or refresh Expert Advisors
3. Compile the EA in MetaEditor (F7) to ensure no errors

### 2. Telegram Setup (Optional)

1. **Create a Telegram Bot**:
   - Message [@BotFather](https://t.me/botfather) on Telegram
   - Send `/newbot` and follow instructions
   - Save your `BOT_TOKEN`

2. **Get Your Chat ID**:
   - Message your bot once
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Find your `chat_id` in the response

3. **Configure EA**:
   - Set `Telegram_Bot_Token` to your bot token
   - Set `Telegram_Chat_ID` to your chat ID
   - Enable `Enable_Telegram = true`

### 3. Attach to Chart

1. Open EURUSD H1 chart (recommended for testing)
2. Drag `TrendFollowingEA` to the chart
3. Configure parameters (see below)
4. Click "OK" and ensure "Allow live trading" is checked

## ⚙️ Parameter Configuration

### Trend Filter Settings
- **TrendEMA_Period** (200): Long-term trend identification
- **FastEMA_Period** (21): Momentum confirmation
- **RSI_Period** (14): Momentum oscillator
- **RSI_Long_Threshold** (55): Minimum RSI for long trades
- **RSI_Short_Threshold** (45): Maximum RSI for short trades
- **Use_MACD_Filter** (true): Additional MACD confirmation

### Entry & Exit Settings
- **StopLoss_Pips** (30): Stop loss distance in pips
- **Risk_Percent** (1.0): Risk per trade as % of balance
- **Max_Concurrent_Trades** (1): Maximum simultaneous positions
- **Enable_Breakeven** (true): Move SL to breakeven after 1xSL profit
- **Enable_Trailing** (false): Enable trailing stop loss
- **Trailing_Start_Pips** (20): Profit to start trailing
- **Trailing_Step_Pips** (10): Trailing step size

### Risk Management
- **Daily_Loss_Limit_Pct** (5.0): Daily loss limit as % of balance
- **Intraday_Close_Time** ("22:00"): Time to close all positions

### Telegram Settings
- **Telegram_Bot_Token**: Your Telegram bot token
- **Telegram_Chat_ID**: Your Telegram chat ID
- **Enable_Telegram** (true): Enable/disable notifications

## 📊 Trading Strategy

### Entry Conditions

**Long Trades** (all conditions must be met):
- Price above 200-period EMA (uptrend)
- 21-period EMA crosses above 200-period EMA
- RSI > 55 (momentum confirmation)
- MACD histogram > 0 (if enabled)

**Short Trades** (all conditions must be met):
- Price below 200-period EMA (downtrend)
- 21-period EMA crosses below 200-period EMA
- RSI < 45 (momentum confirmation)
- MACD histogram < 0 (if enabled)

### Exit Strategy

1. **Take Profit**: 3x stop loss distance
2. **Stop Loss**: Fixed pip distance from entry
3. **Breakeven**: Move SL to entry after 1x SL profit
4. **Trailing Stop**: Optional trailing mechanism
5. **Time Exit**: All positions closed by 22:00 server time

### Risk Management

- **Position Sizing**: Automatically calculated for 1% account risk
- **Daily Limit**: Trading stops if daily loss exceeds limit
- **Maximum Positions**: Configurable concurrent trade limit
- **No Overnight**: Strict intraday-only approach

## 🧪 Backtesting Guide

### Recommended Settings

**Symbol**: EURUSD
**Timeframe**: H1
**Period**: 2020-2025
**Model**: Every tick (most accurate)
**Spread**: Current or fixed at 1-2 pips

### Optimization Parameters

For achieving ≥60% win rate, optimize these parameters:

1. **StopLoss_Pips**: Test range 20-50 pips
2. **RSI thresholds**: Adjust for market conditions
3. **TrendEMA_Period**: Test 150-250 range
4. **FastEMA_Period**: Test 15-30 range

### Performance Metrics to Monitor

- **Win Rate**: Target ≥60%
- **Profit Factor**: Target ≥1.5
- **Maximum Drawdown**: Keep <10%
- **Risk-Reward**: Maintain 1:3 ratio
- **Total Trades**: Minimum 100 for statistical significance

### Strategy Tester Settings

```
Symbol: EURUSD
Period: H1 (1 Hour)
Model: Every tick based on real ticks
Use date: Custom range (2020-2025)
Optimization: Genetic algorithm
Forward testing: 25%
```

## 🔧 Optimization Tips

### If Win Rate < 60%

1. **Tighten Entry Conditions**:
   - Increase RSI thresholds (57/43 instead of 55/45)
   - Add MACD filter requirement
   - Increase minimum trend EMA period

2. **Adjust Stop Loss**:
   - Test smaller SL (20-25 pips) for tighter control
   - Use ATR-based dynamic stops

3. **Filter Market Conditions**:
   - Avoid trading during high-impact news
   - Add volatility filters
   - Consider session-based trading

4. **Timeframe Optimization**:
   - Test on H4 for stronger trends
   - Use M30 for more frequent signals

### Risk Management Enhancements

- Reduce risk to 0.5% per trade during optimization
- Implement correlation filters for multiple pairs
- Add maximum daily trade limits
- Consider equity-based position sizing

## 📱 Telegram Notifications

The EA sends formatted messages for:

### Trade Opened
```
📈 Trade Opened
📊 EURUSD BUY
💱 Entry: 1.08450
🛑 SL: 1.08150
🎯 TP: 1.09350
💰 Size: 0.33 lots
📊 Risk: 1.0%
⏰ 2024-01-15 14:30
```

### Trade Closed
```
✅ Trade Closed - WIN
📊 EURUSD
💱 Close: 1.09350
📈 Pips: +90.0
💰 P/L: +297.00 USD
⏰ 2024-01-15 16:45
```

### EA Status
```
🤖 TrendFollowingEA Started
📊 Symbol: EURUSD
💰 Balance: 10000.00 USD
⚙️ Risk: 1.0%
⏰ 2024-01-15 08:00
```

## ⚠️ Important Notes

### Live Trading Checklist

- [ ] Tested extensively on demo account
- [ ] Achieved target performance metrics
- [ ] Telegram notifications working
- [ ] Correct broker spread/commission settings
- [ ] VPS setup for 24/7 operation
- [ ] Risk parameters verified
- [ ] Emergency stop procedures in place

### Risk Warnings

- **Past Performance**: Does not guarantee future results
- **Market Risk**: All trading involves risk of loss
- **Technology Risk**: EA depends on stable internet/power
- **Broker Risk**: Execution quality affects performance
- **Parameter Risk**: Optimization may lead to curve fitting

### Best Practices

1. **Start Small**: Begin with minimum position sizes
2. **Monitor Closely**: Watch first few trades carefully
3. **Regular Review**: Check performance weekly
4. **Update Parameters**: Adjust based on market changes
5. **Backup Strategy**: Have manual trading plan ready

## 🛠️ Troubleshooting

### Common Issues

**EA Not Trading**:
- Check "Allow live trading" is enabled
- Verify sufficient account balance
- Ensure market is open
- Check daily loss limit not reached

**Telegram Not Working**:
- Verify bot token and chat ID
- Check internet connection
- Ensure WinInet.dll is available
- Test with simple message first

**Poor Performance**:
- Review parameter settings
- Check spread/commission costs
- Verify broker execution quality
- Consider different timeframe/symbol

**Compilation Errors**:
- Ensure all files in correct folders
- Check MQL4 include paths
- Verify MT4 build version
- Update MetaEditor if needed

## 📞 Support

For technical support or questions:

1. Check this README first
2. Review EA logs in MT4 Journal
3. Test on demo account before live trading
4. Verify all parameters and settings

## 📄 License

Copyright 2024, Professional Trading Bot. All rights reserved.

---

**Disclaimer**: Trading foreign exchange carries a high level of risk and may not be suitable for all investors. Past performance is not indicative of future results. Please ensure you fully understand the risks involved.
