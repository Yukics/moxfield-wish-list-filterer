# Moxfield wish list helper

1. Open a new tab and open element inspector: F12
2. Go to: [https://moxfield.com/wishlist](https://moxfield.com/wishlist)
3. Search request https://api2.moxfield.com/v2/wishlist
4. Right click -> Copy -> Copy reponse
5. Paste as response.json on `src/` folder
6. Execute by:
```shell
# requirements jq and csvkit
sudo apt update && sudo apt install -y jq csvkit # for ubuntu, you might use WSL on Windows
cd src
chmod +x main.sh
./main.sh 	    # list format
./main.sh table # md table format
```
 
## Explanation

I do use several tags for keeping track on what I will buy or proxy and what I already bought and is still on track or in my collection

#proxy: means I will not buy that card, probably because it is expensive
#noart: means I do not care the art of that card so any collection is good
#bought: means I already bought it, I am waiting fot its arrival. Once they are on my hands I add them to my collection and remove it from wish list
#decktag: means that card is for <decktag> deck. This kind of tag is used when I am buying new cards, to segregate and prioritize 

Also I have several global tags that i do not want to filter by, so I add them to the script `BASIC_FILTER` variable, ex: destroy, counter and tutor. Feel free to modify

## Technical debt

+ Moxfield API is closed and has Cloudflare protecting it. So any effort on automating this part is meaningless. It would be nice to fully automate it and keep track against CardTrader or CardMarket APIs.