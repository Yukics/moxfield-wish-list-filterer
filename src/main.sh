
#!/bin/bash

FILTER=$1

BASIC_FILTER="proxy bought destroy counter tutor noart" # tags not used for specifying decks
BASIC_FILTER_REGEX="($(echo $BASIC_FILTER|sed 's/ /\|/g'))"

mkdir -p intermediate
# basic formatting https://api2.moxfield.com/v2/wishlist
## flatten json
cat response.json | \
	jq -e '.deck.boards.mainboard.cards
		| to_entries[]
		| .value
		| reduce ( tostream | select(length==2) | .[0] |= [join(".")] ) as [$p,$v] ( {} ; setpath($p; $v) )' | \
	jq -s > intermediate/cards.json
## prepares tags
cat response.json | jq -e '.deck.authorTags | to_entries[] ' | \
	jq 'walk(if type == "object" then with_entries( if .key == "key" then .key = "name" else . end ) else . end)' | \
	jq 'walk(if type == "object" then with_entries( if .key == "value" then .key = "card.tags" else . end ) else . end)' | jq -s > intermediate/tags.json
## merges tags and cards
jq --slurpfile uid intermediate/cards.json '($uid[0] | INDEX(."card.name")) as $dict  | map( $dict[.name] + del(.name) )' intermediate/tags.json > intermediate/merge.json

echo "ALL PROXYS $(cat intermediate/merge.json | jq '.[] | select( [ ."card.tags"[] | contains("proxy") ] | any) | select(has("card.name"))'| jq -s length)"
echo
cat intermediate/merge.json | jq -r '.[] 
	| select( [ ."card.tags"[] 
			| contains("proxy") ] 
			| any) 
	| select(has("card.name")) 
	| "\(.quantity) \(."card.name") (\(."card.set")) \(."card.cn")\t\t\tCT:\(."card.prices.ct")€  CK:\(."card.prices.ck")€ "' | tr -d '"'
echo

echo "ALL BOUGHT $(cat intermediate/merge.json | jq '.[] | select( [ ."card.tags"[] | contains("bought") ] | any) | select(has("card.name"))'| jq -s length)"
echo
cat intermediate/merge.json | jq '.[]
		| select(.["card.tags"] | index("bought"))
		| .["card.tags"] |= map(select(. != "bought"))
		| select(has("card.name"))
		| "\(.quantity) \(."card.name") (\(."card.set")) \(."card.cn") tags:\(.["card.tags"] | join(", "))"' | tr -d '"'
echo

echo "PENDING"
echo
mkdir -p tagged
for TAG in $(cat intermediate/tags.json | jq '.[]."card.tags"[]' | sort -u | tr -d '"' | grep -vE $BASIC_FILTER_REGEX); do

	if [[ "$1" = "table" ]]; then
	cat intermediate/merge.json | jq -r --arg CURRENT_TAG "$TAG" '.[]
		| select((.["card.tags"] | index($CURRENT_TAG))
		and (.["card.tags"] | index("proxy") | not)
		and (.["card.tags"] | index("bought") | not))
		| select(has("card.name"))
		| "\(."quantity");\(."card.name");(\(."card.set"));\(."card.cn");\(."card.prices.ct")€;\(."card.prices.ck")€"' | tr -d '"' > tagged/$TAG.json
	else
	cat intermediate/merge.json | jq -r --arg CURRENT_TAG "$TAG" '.[]
		| select((.["card.tags"] | index($CURRENT_TAG))
		and (.["card.tags"] | index("proxy") | not)
		and (.["card.tags"] | index("bought") | not))
		| select(has("card.name"))
		| "\(."quantity") \(."card.name") (\(."card.set")) \(."card.cn") \t\t\t # CardTrader: \(."card.prices.ct")€ CardMarket: \(."card.prices.ck")€"' | tr -d '"' > tagged/$TAG.json
	fi
	echo "$(echo $TAG | sed 's/.*/\U&/g') $(cat tagged/$TAG.json | wc -l)"
	echo
	if [[ "$1" == "table" ]]; then
		{ echo "Cant;Name;Set;CN;CardTrader;CardMarket"; cat tagged/$TAG.json; } | csvlook --no-inference
	else
		cat tagged/$TAG.json
	fi
	echo
done

