page=0
while true; do
  curl -s "https://huggingface.co/models?other=text-generation-inference&sort=trending&inference=warm&p=$page" |
    grep 'data-target="ModelList"' |
    sed -n 's/.*data-props="\([^"]*\)".*/\1/p' |
    sed 's%&quot;%"%g' |
    jq -e .initialValues.models[].id || break
  ((page++))
done
