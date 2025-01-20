if [ $# -eq 0 ]; then
    echo "Error: authjs.session-token cookie value required."
    echo "Usage: $0 <authjs.session-token>"
    exit 1
fi

curl -s 'https://inference.cerebras.ai/api/graphql' \
  -H 'accept: */*' \
  -H 'content-type: application/json' \
  -H "cookie: authjs.session-token=$1" \
  --data-raw '{"operationName":"GetMyDemoApiKey","variables":{},"query":"query GetMyDemoApiKey {\n  GetMyDemoApiKey\n}"}' \
  | jq -r .data.GetMyDemoApiKey
