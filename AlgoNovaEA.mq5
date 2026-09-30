//+------------------------------------------------------------------+
//| AlgoNova ELITE ICT - XAUUSD | BY SHAHLE                          |
//| Real ICT: Liquidity Sweep + MSB + OB + FVG + Killzone            |
//+------------------------------------------------------------------+
#property copyright "SHAHLE - AlgoNova"
#property version   "3.5"
#property strict

//--- INPUTS
input double   InpLot = 0.10;
input int      InpSL_ATR = 150;      // SL buffer points
input int      InpTP_ATR = 450;      // TP points
input bool     InpUseKillzone = true;
input bool     InpShowPanel = true;

//--- GLOBALS
int atrHandle;
datetime lastBarTime;

//+------------------------------------------------------------------+
void DrawElitePanel(string bias, string signal)
{
   if(!InpShowPanel) return;
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'8,12,20');
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   
   string panel = "AN_PANEL";
   if(ObjectFind(0,panel)!=0){
      ObjectCreate(0,panel,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,panel,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,10);
      ObjectSetInteger(0,panel,OBJPROP_XSIZE,260);
      ObjectSetInteger(0,panel,OBJPROP_YSIZE,125);
      ObjectSetInteger(0,panel,OBJPROP_BGCOLOR,C'18,25,35');
      ObjectSetInteger(0,panel,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   }
   
   DrawLabel("AN_L1",20,20,"ALGO NOVA X • ELITE ICT",clrAqua,14,"Arial Black");
   DrawLabel("AN_L2",20,48,"SYMBOL: "+_Symbol+" | XAU M15",clrWhite,10);
   DrawLabel("AN_L3",20,68,"HTF BIAS: "+bias, bias=="BULLISH"?clrLime:clrOrangeRed,11);
   DrawLabel("AN_L4",20,86,"SIGNAL: "+signal, clrWhite,10);
   DrawLabel("AN_L5",20,104,"LOT: "+DoubleToString(InpLot,2)+" | SHAHLE VER 3.5",clrSilver,8);
}

void DrawLabel(string name,int x,int y,string text,color clr,int size,string font="Arial")
{
   if(ObjectFind(0,name)!=0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_FONT,font);
}

//+------------------------------------------------------------------+
bool IsKillzone()
{
   if(!InpUseKillzone) return true;
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   // London Killzone 8-11, NY Killzone 13-16 GMT
   return ( (hour>=8 && hour<=11) || (hour>=13 && hour<=16) );
}

bool CheckLiquiditySweep(bool bullish)
{
   // Check if previous high/low was swept
   double high1 = iHigh(_Symbol,_Period,1);
   double high2 = iHigh(_Symbol,_Period,2);
   double low1 = iLow(_Symbol,_Period,1);
   double low2 = iLow(_Symbol,_Period,2);
   if(bullish) return (low1 < low2 && iClose(_Symbol,_Period,1) > low2); // Sell-side sweep
   else return (high1 > high2 && iClose(_Symbol,_Period,1) < high2); // Buy-side sweep
}

bool CheckFVG(bool bullish)
{
   double c1 = iClose(_Symbol,_Period,1);
   double c3 = iClose(_Symbol,_Period,3);
   double h3 = iHigh(_Symbol,_Period,3);
   double l3 = iLow(_Symbol,_Period,3);
   if(bullish) return (iLow(_Symbol,_Period,1) > h3); // Bullish FVG
   else return (iHigh(_Symbol,_Period,1) < l3); // Bearish FVG
}

string GetHTFBias()
{
   double ema200 = iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
   double price = iClose(_Symbol,_Period,1);
   return (price > ema200 ? "BULLISH" : "BEARISH");
}

void TryEnter()
{
   if(PositionsTotal()>=2) return; // Max 2 trades
   if(!IsKillzone()) { DrawElitePanel(GetHTFBias(),"WAIT KILLZONE"); return; }
   
   string bias = GetHTFBias();
   bool buySweep = CheckLiquiditySweep(true);
   bool sellSweep = CheckLiquiditySweep(false);
   bool bullFVG = CheckFVG(true);
   bool bearFVG = CheckFVG(false);
   
   string signal = "SCANNING";
   if(bias=="BULLISH" && buySweep && bullFVG)
   {
      signal = "BUY CONFIRMED";
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl = ask - InpSL_ATR * _Point * 10;
      double tp = ask + InpTP_ATR * _Point * 10;
      MqlTradeRequest req; MqlTradeResult res;
      ZeroMemory(req);
      req.action = TRADE_ACTION_DEAL; req.symbol=_Symbol; req.volume=InpLot;
      req.type=ORDER_TYPE_BUY; req.price=ask; req.sl=sl; req.tp=tp;
      req.deviation=30; req.magic=202604; req.comment="AlgoNova ICT BUY";
      OrderSend(req,res);
   }
   else if(bias=="BEARISH" && sellSweep && bearFVG)
   {
      signal = "SELL CONFIRMED";
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl = bid + InpSL_ATR * _Point * 10;
      double tp = bid - InpTP_ATR * _Point * 10;
      MqlTradeRequest req; MqlTradeResult res;
      ZeroMemory(req);
      req.action = TRADE_ACTION_DEAL; req.symbol=_Symbol; req.volume=InpLot;
      req.type=ORDER_TYPE_SELL; req.price=bid; req.sl=sl; req.tp=tp;
      req.deviation=30; req.magic=202604; req.comment="AlgoNova ICT SELL";
      OrderSend(req,res);
   }
   
   DrawElitePanel(bias,signal);
}

//+------------------------------------------------------------------+
int OnInit()
{
   atrHandle = iATR(_Symbol,_Period,14);
   DrawElitePanel("LOADING","INIT");
   Print("AlgoNova Elite ICT Loaded - XAUUSD Ready");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,0,-1);
   IndicatorRelease(atrHandle);
}

void OnTick()
{
   datetime currBar = iTime(_Symbol,_Period,0);
   if(currBar==lastBarTime) return;
   lastBarTime=currBar;
   TryEnter();
}
