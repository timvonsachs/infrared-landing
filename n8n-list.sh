curl -sS "https://timvonsachs.app.n8n.cloud/mcp-server/http" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI3NzlkYTQ5Ny0wYzBjLTRlN2YtYTVkYy1mZjZiY2VkMDgxMTkiLCJpc3MiOiJuOG4iLCJhdWQiOiJtY3Atc2VydmVyLWFwaSIsImp0aSI6IjgyNjE4MjU3LWVhMmEtNDk5NS04MjdiLWUyNWI5ZWQ3MThlMSIsImlhdCI6MTc4NjM5NDE2OX0.39SKqL-z9xZT639a26j53ABafdNQUb3TuP8P8S3tRaA" \
  -H "Accept: application/json, text/event-stream" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"tools/call",
    "params":{
      "name":"search_workflows",
      "arguments":{"search":"resonance"}
    },
    "id":1
  }'