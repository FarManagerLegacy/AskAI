if [ $# -eq 0 ]; then
    echo "Error: authjs.session-token cookie value required."
    echo "Usage: $0 <authjs.session-token>"
    exit 1
fi

curl -s 'https://chat.cerebras.ai/api/auth/session' \
  -b "authjs.session-token=$1" | jq
