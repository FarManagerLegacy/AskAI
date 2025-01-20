#https://cloud.sambanova.ai/_next/static/chunks/328-7c699810e3f38525.js
curl -s 'https://cloud.sambanova.ai/_next/static/chunks/226-382743930c4a3f96.js' \
  | sed -n 's/.*MODEL_NAME_KEY_MAP:\({[^}]*}\).*/\1/p' \
  | jq keys
