if [ $# -eq 0 ]; then
    echo "Error: g4f_session local storage value required."
    echo "Usage: $0 <g4f_session>"
    exit 1
fi

curl -s 'https://auth.gpt4free.workers.dev/members/api/rate-limit' \
    -H "authorization: Bearer $1" | jq
