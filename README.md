# echidna-spider

## Usage

### Run spider:

```bash
bin/spider
```

Check header part of `bin/spider` for configurable environment variables.

### Add a Tencent Weibo agent

```bash
curl 'http://localhost:9000/agents/tencent/new'
# => {"authorize_url":"https://open.t.qq.com/cgi-bin/oauth2/authorize?response_type=code&client_id=801317572&redirect_uri=http%3A%2F%2Flocalhost%3A9000%2Fagents%2Ftencent%2Fcreate"}
```

Visit `authorize_url` in your browser to complete the OAuth process to authenticate agent's Tencent Weibo account.

Tencent Weibo Agent will fetch new tweets from it's home timeline and publish to `:add_tweet` channel every 5 seconds.
