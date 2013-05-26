#include <sourcemod>
#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source - Engine - Menu Shopmenu",
    author = "War3Source Team",
    description = "Shows the shopmenu"
};

new Handle:hUseCategorysCvar;
new String:sBuyItemSound[256];
new WantsToBuy[MAXPLAYERSCUSTOM];

public OnPluginStart()
{
    LoadTranslations("w3s.engine.menushopmenu.txt");
    
    hUseCategorysCvar = CreateConVar("war3_buyitems_category", "0", "Enable/Disable shopitem categorys", 0, true, 0.0, true, 1.0);
}

public OnMapStart()
{
    War3_AddSoundFolder(sBuyItemSound, sizeof(sBuyItemSound), "ui/ReceiveGold.mp3");
    War3_PrecacheSound(sBuyItemSound);
}

public OnWar3Event(W3EVENT:event,client)
{
    if(event == DoShowShopMenu) 
    {
        new bool:useCategory = GetConVarBool(hUseCategorysCvar);
        if (useCategory)
        {
            ShowMenuShopCategory(client);
        }
        else
        {
            ShowMenuShop(client);
        }
    }
    if(event == DoTriedToBuyItem) 
    {
        War3_TriedToBuyItem(client, W3GetVar(EventArg1), W3GetVar(EventArg2)); ///ALWAYS SET ARG2 before calling this event
    }
}

SetShopMenuTitle(client, Handle:menu)
{
    new itemsOwned = GetClientItemsOwned(client);
    new maxItems = GetMaxShopitemsPerPlayer();
    
    new currency = War3_GetCurrency(client);
    new maxCurrency = War3_GetMaxCurrency();
    
    new String:title[300];
    Format(title, sizeof(title), "%T\n", "[War3Source] Browse the itemshop. You have {amount}/{amount} items", GetTrans(), itemsOwned, maxItems);
    Format(title, sizeof(title), "%s%T", title, "Your current balance: {amount}/{maxamount}", GetTrans(), currency, maxCurrency);

    SetSafeMenuTitle(menu, title);
}

ShowMenuShopCategory(client)
{
    SetTrans(client);
    new Handle:shopMenu = CreateMenu(War3Source_ShopMenuCategory_Sel);
    SetMenuExitButton(shopMenu, true);
    SetShopMenuTitle(client, shopMenu);

    new Handle:h_ItemCategorys = CreateArray(ByteCountToCells(64));
    decl String:category[64];
    new ItemsLoaded = W3GetItemsLoaded();

    // find all possible categorys and fill the menu
    for(new x=1; x <= ItemsLoaded; x++)
    {
        if(!W3IsItemDisabledGlobal(x) && !W3ItemHasFlag(x, "hidden"))
        {
            W3GetItemCategory(x, category, sizeof(category));

            if ((FindStringInArray(h_ItemCategorys, category) >= 0) || StrEqual(category, ""))
            {
                continue;
            }
            else
            {
                PushArrayString(h_ItemCategorys, category);
            }
        }
    }

    // fill the menu with the categorys
    while(GetArraySize(h_ItemCategorys))
    {
        GetArrayString(h_ItemCategorys, 0, category, sizeof(category));

        AddMenuItem(shopMenu, category, category, ITEMDRAW_DEFAULT);
        RemoveFromArray(h_ItemCategorys, 0);
    }

    CloseHandle(h_ItemCategorys);

    DisplayMenu(shopMenu, client, 20);
}

ShowMenuShop(client, const String:category[]="") 
{
    SetTrans(client);
    new Handle:shopMenu = CreateMenu(War3Source_ShopMenu_Selected);
    SetMenuExitButton(shopMenu, true);
    SetShopMenuTitle(client, shopMenu);

    decl String:itemname[64];
    decl String:itembuf[4];
    decl String:linestr[96];
    decl String:itemcategory[64];
    decl cost;
    new ItemsLoaded = W3GetItemsLoaded();
    for(new x=1; x <= ItemsLoaded; x++)
    {
        if(!W3IsItemDisabledGlobal(x) && !W3ItemHasFlag(x, "hidden")) 
        {
            W3GetItemCategory(x, itemcategory, sizeof(itemcategory));

            if ((!StrEqual(category, "") && StrEqual(category, itemcategory)) || (StrEqual(category, "")))
            {
                Format(itembuf, sizeof(itembuf), "%d" ,x);
                W3GetItemName(x, itemname, sizeof(itemname));
                cost = W3GetItemCost(x);
                
                Format(linestr, sizeof(linestr), "%T", "{itemname} - Cost: {amount}", client, itemname, cost);
                
                if(War3_GetOwnsItem(client,x)) 
                {
                    Format(linestr, sizeof(linestr),">%s", linestr);
                }
                new itemdraw;
                if (W3IsItemDisabledForRace(War3_GetRace(client), x) || W3IsItemDisabledGlobal(x) || War3_GetOwnsItem(client,x))
                {
                    itemdraw = ITEMDRAW_DISABLED;
                }
                else
                {
                    itemdraw = ITEMDRAW_DEFAULT;
                }
                
                AddMenuItem(shopMenu, itembuf, linestr, itemdraw);
            }
        }
    }
    DisplayMenu(shopMenu, client, 20);
}

public War3Source_ShopMenu_Selected(Handle:menu,MenuAction:action,client,selection)
{
    if(action == MenuAction_Select)
    {
        if(ValidPlayer(client))
        {
            decl String:SelectionInfo[4];
            decl String:SelectionDispText[256];
            new SelectionStyle;
            
            GetMenuItem(menu, selection, SelectionInfo, sizeof(SelectionInfo), SelectionStyle, SelectionDispText, sizeof(SelectionDispText));
            new item = StringToInt(SelectionInfo);
            
            War3_TriedToBuyItem(client, item, true);
        }
    }
    if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public War3Source_ShopMenuCategory_Sel(Handle:menu, MenuAction:action, client, selection)
{
    if(action == MenuAction_Select)
    {
        if(ValidPlayer(client))
        {
            decl String:SelectionInfo[64];
            decl String:SelectionDispText[256];
            new SelectionStyle;
            GetMenuItem(menu, selection, SelectionInfo, sizeof(SelectionInfo), SelectionStyle, SelectionDispText,sizeof(SelectionDispText));

            ShowMenuShop(client, SelectionInfo);
        }
    }
    if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

War3_TriedToBuyItem(client, item, bool:reshowmenu=true)
{
    if(item > 0 && item <= W3GetItemsLoaded())
    {
        SetTrans(client);

        decl String:itemname[64];
        W3GetItemName(item,itemname,sizeof(itemname));

        new currency = War3_GetCurrency(client);
        new cost = W3GetItemCost(item);
    
        W3SetVar(EventArg1, item);
        new bool:bCanBuy = W3Denyable(DN_CanBuyItem1, client);

        new race=War3_GetRace(client);
        if(W3IsItemDisabledGlobal(item)) 
        {
            War3_ChatMessage(client, "%T", "{itemname} is disabled", GetTrans(), itemname);
            bCanBuy = false;
        }

        else if(W3IsItemDisabledForRace(race,item)) 
        {
            new String:racename[64];
            War3_GetRaceName(race, racename, sizeof(racename));
            War3_ChatMessage(client, "%T", "You may not purchase {itemname} when you are {racename}", GetTrans(), itemname, racename);
            bCanBuy = false;
        }
        else if(War3_GetOwnsItem(client, item)) 
        {
            War3_ChatMessage(client ,"%T", "You already own {itemname}", GetTrans(), itemname);
            bCanBuy = false;
        }
        else if(currency < cost) 
        {
            War3_ChatMessage(client, "%T", "You cannot afford {itemname}", GetTrans(), itemname);
            if(reshowmenu) 
            {
                ShowMenuShop(client);
            }
            bCanBuy = false;
        }
        
        if(bCanBuy) 
        {
            W3SetVar(EventArg1, item);
            W3SetVar(EventArg2, 1);
            W3CreateEvent(CanBuyItem, client);
            if(W3GetVar(EventArg2) == 0) 
            {
                bCanBuy = false;
            }
        }
        //if its use instantly then let them buy it
        //items maxed out
        if(bCanBuy && !War3_GetItemProperty(item, ITEM_USED_ON_BUY) && GetClientItemsOwned(client) >= GetMaxShopitemsPerPlayer()) 
        {
            bCanBuy = false;
            WantsToBuy[client] = item;
            War3M_ExceededMaxItemsMenuBuy(client);

        }

        if(bCanBuy) 
        {
            War3_SubstractCurrency(client, cost);
            War3_ChatMessage(client, "%T", "You have successfully purchased {itemname}", GetTrans(), itemname);

            if (IsPlayerAlive(client))
            {
                EmitSoundToAll(sBuyItemSound, client);
            }
            else
            {
                EmitSoundToClient(client, sBuyItemSound);
            }
            
            W3SetVar(TheItemBoughtOrLost,item);
            W3CreateEvent(DoForwardClientBoughtItem,client); //old item//forward, and set has item true inside
        }
    }
}

War3M_ExceededMaxItemsMenuBuy(client)
{
    SetTrans(client);
    new Handle:hMenu=CreateMenu(OnSelectExceededMaxItemsMenuBuy);
    SetMenuExitButton(hMenu,true);

    decl String:itemname[64];
    W3GetItemName(WantsToBuy[client],itemname,sizeof(itemname));

    SetSafeMenuTitle(hMenu,"%T\n","[War3Source] You already have a max of {amount} items. Choose an item to replace with {itemname}. You will not get money back",GetTrans(),GetMaxShopitemsPerPlayer(),itemname);

    decl String:itembuf[4];
    decl String:linestr[96];
    new ItemsLoaded = W3GetItemsLoaded();
    for(new x=1;x<=ItemsLoaded;x++)
    {
        if(War3_GetOwnsItem(client,x)) {
            Format(itembuf,sizeof(itembuf),"%d",x);
            W3GetItemName(x,itemname,sizeof(itemname));

            Format(linestr,sizeof(linestr),"%s",itemname);
            AddMenuItem(hMenu,itembuf,linestr);
        }
    }
    DisplayMenu(hMenu,client,20);
}
public OnSelectExceededMaxItemsMenuBuy(Handle:menu,MenuAction:action,client,selection)
{
    if(action==MenuAction_Select)
    {
        if(ValidPlayer(client))
        {
            SetTrans(client);
            decl String:SelectionInfo[4];
            decl String:SelectionDispText[256];
            new SelectionStyle;
            GetMenuItem(menu,selection,SelectionInfo,sizeof(SelectionInfo),SelectionStyle, SelectionDispText,sizeof(SelectionDispText));
            new itemtolose=StringToInt(SelectionInfo);
            if(itemtolose>0&&itemtolose<=W3GetItemsLoaded())
            {
                //check he can afford new item
                new currency = War3_GetCurrency(client);
                new cost = W3GetItemCost(WantsToBuy[client]);
                decl String:itemname[64];
                W3GetItemName(WantsToBuy[client],itemname,sizeof(itemname));

                if(currency < currency) {
                    War3_ChatMessage(client,"%T","You cannot afford {itemname}",GetTrans(),itemname);
                    ShowMenuShop(client);
                }
                else {
                    W3SetVar(TheItemBoughtOrLost,itemtolose);
                    W3CreateEvent(DoForwardClientLostItem,client); //old item

                    War3_SubstractCurrency(client, cost);
                    War3_ChatMessage(client,"%T","You have successfully purchased {itemname}",GetTrans(),itemname);

                    W3SetVar(TheItemBoughtOrLost,WantsToBuy[client]);
                    W3CreateEvent(DoForwardClientBoughtItem,client); //old item
                }
            }
        }
    }
}
