if [ $# -eq 0 ]; then
    echo "Error: authjs.session-token cookie value required."
    echo "Usage: $0 <authjs.session-token>"
    exit 1
fi

curl -s 'https://chat.cerebras.ai/api/graphql' \
  -H 'content-type: application/json' \
  -b "authjs.session-token=$1" \
  --data-raw '{"operationName":"ListMyRegions","variables":{},"query":"query ListMyRegions {\n  ListMyRegions {\n    id\n    name\n    baseApiUrl\n    __typename\n  }\n}"}'
  
