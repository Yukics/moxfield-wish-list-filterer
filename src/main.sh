
#!/bin/bash

FILTER=$1

BASIC_FILTER="proxy bought destroy counter tutor noart" # tags not used for specifying decks
BASIC_FILTER_REGEX="($(echo $BASIC_FILTER|sed 's/ /\|/g'))"

PROXY="no"
BOUGHT="no"
TABLE="no"
HIDE="no"

while getopts "tpbh" opt; do
  case $opt in
    t) TABLE="yes" ;;
    p) PROXY="yes" ;;
    b) BOUGHT="yes" ;;
	h) HIDE="yes" ;;
    \?)
      echo "Error: Invalid option -$OPTARG"
      usage
      exit 1
      ;;
  esac
done

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
## and removes extra decimals from prices
jq --slurpfile uid intermediate/cards.json '($uid[0] | INDEX(."card.name")) as $dict  | map( $dict[.name] + del(.name) )' intermediate/tags.json \
	| sed -E 's/([-+]?[0-9]+\.[0-9]{2})[0-9]{2}\b/\1/g' > intermediate/merge.json

# PROXY reports if requested
if [[ "$PROXY" == "yes" ]]; then
	echo "ALL PROXYS $(cat intermediate/merge.json | jq '.[] | select( [ ."card.tags"[] | contains("proxy") ] | any) | select(has("card.name"))'| jq -s length)"
	echo
	{ echo "Cant;Name;Set;CN;CardTrader;CardMarket;Tags";
	cat intermediate/merge.json | jq -r '.[] 
		| select( [ ."card.tags"[] 
				| contains("proxy") ] 
				| any) 
		| select(has("card.name")) 
		| "\(.quantity);\(."card.name");(\(."card.set"));\(."card.cn");\(."card.prices.ct")€;\(."card.prices.ck")€;\(.["card.tags"] | join(","))"'; }  | column -s ';' -t
	echo
fi

# BOUGHT reports if requested
if [[ "$BOUGHT" == "yes" ]]; then
	echo "ALL BOUGHT $(cat intermediate/merge.json | jq '.[] | select( [ ."card.tags"[] | contains("bought") ] | any) | select(has("card.name"))'| jq -s length)"
	echo
	{ echo "Cant;Name;Set;CN;Tags";
	cat intermediate/merge.json | jq -r '.[]
			| select(.["card.tags"] | index("bought"))
			| .["card.tags"] |= map(select(. != "bought"))
			| select(has("card.name"))
			| "\(.quantity);\(."card.name");(\(."card.set"));\(."card.cn");\(.["card.tags"] | join(","))"'; } | column -s ';' -t
	echo
fi

# TAGGED reports
if [[ "$HIDE" == "yes" ]]; then
	exit 0
fi
echo
mkdir -p tagged
for TAG in $(cat intermediate/tags.json | jq '.[]."card.tags"[]' | sort -u | tr -d '"' | grep -vE $BASIC_FILTER_REGEX); do

	cat intermediate/merge.json | jq -r --arg CURRENT_TAG "$TAG" '.[]
		| select((.["card.tags"] | index($CURRENT_TAG))
		and (.["card.tags"] | index("proxy") | not)
		and (.["card.tags"] | index("bought") | not))
		| select(has("card.name"))
		| "\(."quantity");\(."card.name");(\(."card.set"));\(."card.cn");#;\(."card.prices.ct")€;\(."card.prices.ck")€;\(.["card.tags"] | join(","))"' | tr -d '"' > tagged/$TAG.json

	echo "$(echo $TAG | sed 's/.*/\U&/g') $(cat tagged/$TAG.json | wc -l)"
	echo
	HEADER="Cant;Name;Set;CN;#;CardTrader;CardMarket;Tags"
	if [[ "$TABLE" == "yes" ]]; then
		{ echo $HEADER; cat tagged/$TAG.json; } | csvlook --no-inference
	else
		{ echo $HEADER; cat tagged/$TAG.json; } | column -s ';' -t
	fi
	echo
done

