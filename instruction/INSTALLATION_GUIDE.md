# TrendFollowingEA - Installation Guide

Step-by-step instructions for installing and configuring the TrendFollowingEA.

## 📁 File Structure

After installation, your MT4 folder should contain:

```
MetaTrader 4/
├── MQL4/
│   ├── Experts/
│   │   └── TrendFollowingEA.mq4
│   └── Include/
│       └── TelegramAPI.mqh
└── Files/
    ├── README.md
    ├── BACKTESTING_GUIDE.md
    ├── OPTIMAL_PARAMETERS.txt
    └── INSTALLATION_GUIDE.md
```

## 🚀 Quick Installation

### Step 1: Locate MT4 Data Folder

1. Open MetaTrader 4
2. Go to **File → Open Data Folder**
3. This opens your MT4 data directory

### Step 2: Copy Files

1. **Copy Expert Advisor**:
   - Place `TrendFollowingEA.mq4` in `MQL4/Experts/` folder

2. **Copy Include File**:
   - Place `TelegramAPI.mqh` in `MQL4/Include/` folder

3. **Copy Documentation** (Optional):
   - Place all `.md` and `.txt` files in `Files/` folder

### Step 3: Compile EA

1. Open **MetaEditor** (F4 in MT4)
2. Navigate to **Experts** folder
3. Double-click `TrendFollowingEA.mq4`
4. Press **F7** to compile
5. Check for **0 errors, 0 warnings** in results

### Step 4: Refresh MT4

1. In MT4, go to **View → Navigator**
2. Right-click **Expert Advisors** section
3. Select **Refresh**
4. `TrendFollowingEA` should now appear in the list

## ⚙️ Initial Configuration

### Telegram Setup (Recommended)

1. **Create Telegram Bot**:
   ```
   1. Open Telegram app
   2. Search for @BotFather
   3. Send: /newbot
   4. Follow instructions
   5. Save your BOT_TOKEN
   ```

2. **Get Chat ID**:
   ```
   1. Send a message to your bot
   2. Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   3. Find "chat":{"id":YOUR_CHAT_ID}
   4. Save your CHAT_ID
   ```

3. **Test Connection** (Optional):
   ```
   Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage?chat_id=<YOUR_CHAT_ID>&text=Test
   Should receive "Test" message in Telegram
   ```

### First Attachment

1. **Open EURUSD H1 Chart**:
   - File → New Chart → EURUSD
   - Set timeframe to H1

2. **Attach EA**:
   - Drag `TrendFollowingEA` from Navigator to chart
   - EA properties dialog will open

3. **Configure Parameters**:
   ```
   Common Tab:
   ☑ Allow live trading
   ☐ Allow DLL imports (not needed)
   ☐ Allow imports of external experts (not needed)

   Inputs Tab:
   Use BALANCED setup from OPTIMAL_PARAMETERS.txt
   Set your Telegram_Bot_Token and Telegram_Chat_ID
   ```

4. **Click OK**:
   - EA should attach with smiley face icon
   - Check Journal tab for initialization message

## ✅ Verification Checklist

### EA Attached Successfully
- [ ] Smiley face icon visible in top-right corner of chart
- [ ] No error messages in Journal tab
- [ ] EA name appears in Expert Advisors list

### Settings Configured
- [ ] Stop loss and risk parameters set
- [ ] Telegram credentials entered (if using)
- [ ] Intraday close time appropriate for your timezone
- [ ] Magic number unique (if running multiple EAs)

### Testing Ready
- [ ] Demo account recommended for initial testing
- [ ] Sufficient balance for calculated lot sizes
- [ ] Internet connection stable
- [ ] MT4 allowed through firewall (for Telegram)

## 🔧 Troubleshooting

### EA Won't Attach
**Issue**: Compilation errors
**Solution**:
- Check all files are in correct folders
- Ensure `TelegramAPI.mqh` is in Include folder
- Recompile EA in MetaEditor

### No Trading Activity
**Issue**: EA attached but not trading
**Solutions**:
- Verify "Allow live trading" is checked
- Check if market is open
- Ensure sufficient account balance
- Review RSI and EMA conditions on current chart

### Telegram Not Working
**Issue**: No notifications received
**Solutions**:
- Verify bot token and chat ID are correct
- Test connection manually first
- Check internet/firewall settings
- Ensure Enable_Telegram = true

### Poor Performance
**Issue**: Unexpected results
**Solutions**:
- Verify correct symbol and timeframe (EURUSD H1 recommended)
- Check spread/commission settings
- Review optimization parameters
- Test on demo account first

## 📊 Performance Monitoring

### Daily Checks
- Review trades in MT4 Journal
- Check Telegram notifications (if enabled)
- Monitor drawdown levels
- Verify EA still active (smiley face icon)

### Weekly Analysis
- Calculate win rate from trade history
- Review profit factor trends
- Check maximum consecutive losses
- Analyze performance vs expectations

### Monthly Review
- Compare to backtesting results
- Consider parameter adjustments
- Evaluate different market conditions
- Plan optimization if needed

## 🚨 Safety Reminders

### Before Live Trading
- [ ] Extensive demo testing completed
- [ ] Telegram notifications working
- [ ] Risk parameters validated
- [ ] Emergency procedures planned
- [ ] Performance meets expectations

### Risk Management
- [ ] Never risk more than you can afford to lose
- [ ] Keep position sizes reasonable
- [ ] Monitor daily loss limits
- [ ] Have manual override plan
- [ ] Regular strategy review scheduled

### Technical Considerations
- [ ] VPS recommended for 24/7 operation
- [ ] Backup MT4 installation available
- [ ] Regular EA updates checked
- [ ] Broker execution quality verified
- [ ] Spread/commission costs factored

## 📞 Support Resources

### Documentation Order
1. **Start Here**: README.md - Overview and basic setup
2. **Installation**: This guide - Step-by-step setup
3. **Optimization**: BACKTESTING_GUIDE.md - Performance tuning
4. **Parameters**: OPTIMAL_PARAMETERS.txt - Ready-to-use configurations

### Common Questions

**Q: Which timeframe should I use?**
A: H1 (1-hour) is recommended and optimized for. H4 can work for longer-term trends.

**Q: Can I run on multiple pairs?**
A: Yes, but test each pair separately first. Use different magic numbers.

**Q: How much capital do I need?**
A: Minimum $1000 for meaningful lot sizes with 1% risk. $5000+ recommended.

**Q: Is VPS necessary?**
A: Not required but highly recommended for consistent operation and Telegram notifications.

**Q: Can I modify the code?**
A: Yes, but test thoroughly. Keep backups of original files.

---

**Ready to Trade?** Follow the checklist above, start with demo testing, and gradually transition to live trading once you're comfortable with the EA's performance.
