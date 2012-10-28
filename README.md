# Shapado

Free and open source Q&A software. Hosted at http://shapado.com/


## Dependencies

- git >= 1.5
- ruby >= 1.9.2
- rubygems >= 1.3.7
- bundler
- mongodb >= 1.7
- ruby on rails 3

## Getting Started

### Download the sources:

```bash
git clone git://gitorious.org/shapado/shapado.git

cd shapado/
```

### Configure the application

```bash
cp config/shapado.sample.yml config/shapado.yml
cp config/mongoid.sample.yml config/mongoid.yml
cp config/auth_providers.sample.yml config/auth_providers.yml
```

Edit `shapado.yml` and `auth_providers.yml`

### Setup New Relic

Go to https://rpm.newrelic.com/ and create an account, then:

```bash
cp config/shapado.yml.sample config/newrelic.yml
```

If you don't want to use newrelic, just comment it out in the `Gemfile`.

Otherwise, go to https://rpm.newrelic.com/ and create an account, then:

```bash
cp config/shapado.yml.sample config/newrelic.yml
```

### Install dependencies

```bash
gem install bundler    # (if bundler is not installed)
bundle install
```

### Load default data

```bash
rake bootstrap RAILS_ENV=development
```

### Add default subdomain to `/etc/hosts`, for example:

```
"0.0.0.0 localhost.lan group1.localhost.lan group2.localhost.lan"
```

### Start the server

```bash
rails server -e development
```

When running shapado in production, you need to run:

```bash
jammit
```

## Postfix config

Add the following text to `/etc/aliases`

```
shapado: "|/usr/local/rvm/bin/rvm 1.9.2 exec PATH/to/shapado/script/handle_email"
```

Add the following to `/etc/postfix/main.cf`:

```
default_privs = shapado
```

Then, type:

```bash
sudo newaliases
```


## Follow us on:

* http://twitter.com/shapado

* http://identi.ca/shapado

* http://blog.ricodigo.com/shapado

## Talk to us at:

* irc://irc.freenode.org/shapado

* http://shapado.com/chat

* contact \aT/ shapado d0t com

Report bugs at http://shapado.com and use the tags "bug" or "feature-request"


Happy hacking!
