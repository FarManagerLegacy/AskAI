LIMIT=20000
DATAFILE="sambanova.in"

getModels() {
  curl -s https://cloud.sambanova.ai/_next/$1 |
    sed -n 's/.*MODEL_NAME_KEY_MAP:\({[^}]*}\).*/\1/p' |
    jq -e keys
}

checkSize() {
  size=$(curl -sI https://cloud.sambanova.ai/_next/$1 | grep Content-Length | awk '{print $2}')
  echo -n " ($size)"
  [[ "$size" -lt $LIMIT ]]
} 

getModels $(< $DATAFILE) && exit 0

for item in $(curl -s https://cloud.sambanova.ai/ | grep -oE 'static/chunks/[0-9]+-[a-fA-F0-9]+\.js'); do
  echo -n ${item}
  if checkSize ${item}; then
    echo ...
    getModels ${item} && echo ${item} > $DATAFILE && exit 0
  else
    echo : too big
  fi
done
exit 1
