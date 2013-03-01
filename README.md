# echidna-spider

## Setup

Install redis-server on Debian

```bash
sudo apt-get install redis-server
```

Or on Mac OS X

```bash
brew install redis
```

### Ruby Environment Setup

<https://github.com/transist/echidna/wiki/Ruby-Environment-Setup>

## Usage

### Create Tencent Weibo account

Visit http://t.qq.com and sign up to create an Tencent Weibo account, this account will be used as Tencent Weibo client developer account and Tencent Weibo agent account later.

### Create Tencent Weibo app

* Visit https://open.t.qq.com/ and sign in with the account just created.
* Click "我的应用" to register as developer for the first time.
* Click "我的应用" again to create an app. (Tencent changed their policy recently, and seems only mobile app meet our needs.)

### Run spider

```bash
bin/spider
```

Notable environment variables for configuration:

    ECHIDNA_SPIDER_TENCENT_APP_KEY
    ECHIDNA_SPIDER_TENCENT_APP_SECRET

The app key and secret of Tencent Weibo app created from https://open.t.qq.com/

    ECHIDNA_SPIDER_TENCENT_REDIRECT_URI='http://localhost:9000/agents/tencent/create'

The redirect uri after complete OAuth process from https://open.t.qq.com, set hostname to a domain name or external IP address to make sure the uri is accessable from your browser.

Check header part of `bin/spider` for other configurable environment variables.

### Add a Tencent Weibo agent

```bash
curl 'http://localhost:9000/agents/tencent/new'
# => {"authorize_url":"https://open.t.qq.com/cgi-bin/oauth2/authorize?response_type=code&client_id=801317572&redirect_uri=http%3A%2F%2Flocalhost%3A9000%2Fagents%2Ftencent%2Fcreate"}
```

Visit `authorize_url` in your browser, sign in with the Tencent Weibo account just created, to complete the OAuth process to authenticate the agent.

Each Tencent Weibo agent will gather new tweets from its home timeline and publish to `:add_tweet` channel every 5 seconds.
