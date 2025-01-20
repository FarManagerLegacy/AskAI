if [ $# -eq 0 ]; then
    echo "Error: authjs.session-token cookie value required."
    echo "Usage: $0 <authjs.session-token>"
    exit 1
fi

curl -s 'https://inference.cerebras.ai/api/graphql' \
  -H 'content-type: application/json' \
  -H "cookie: authjs.session-token=$1" \
  --data-raw '{"operationName":"ListModels","variables":{"organizationId":"__personal"},"query":"query ListModels($organizationId: ID) {\n  ListModels(organizationId: $organizationId) {\n    id\n    name\n    description\n    modelVisibility\n    __typename\n  }\n}"}' \
  | jq [.data.ListModels[].id]
