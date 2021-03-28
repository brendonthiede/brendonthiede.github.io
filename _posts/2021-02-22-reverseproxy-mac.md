---
layout: post
title:  "Configuring Apache as a Reverse Proxy on Mac"
date:   2021-02-22T05:25:33.611Z
categories: devops
image: network-switch.jpg
---
Sometimes it may be useful to use your own local certificate for certain testing, or you may want to present multiple sites as own domain to deal with cross origin resource sharing. These are some of the problems that can be solved with a reverse proxy. This explanation takes the perspective of a Mac user running the default Apache web server ([instructions for basic setup](https://discussions.apple.com/docs/DOC-250001766)). There will be three sections: Virtual Hosts, TLS, and Reverse Proxy.

## Virtual Hosts

Virtual hosts, or vhosts, need to be enabled within the `httpd.conf` and then added to `httpd-vhosts.conf`. You will need to start editing `/private/etc/apache2/httpd.conf` as root, e.g. `sudo vi /private/etc/apache2/httpd.conf`, so that you can uncomment (remove the `#` at the start of the line) or add the following:

```ini
LoadModule log_config_module libexec/apache2/mod_log_config.so
LoadModule vhost_alias_module libexec/apache2/mod_vhost_alias.so
Include /private/etc/apache2/extra/httpd-vhosts.conf
```

Now that the web server knows about `/private/etc/apache2/extra/httpd-vhosts.conf` you can add your own virtual host to the bottom of the file (though you probably want to remove the example entries as the DocumentRoot probably doesn't exist):

```xml
<VirtualHost *:80>
    ServerName local.example.com
</VirtualHost>
```

Here I am leaving everything but the ServerName at the defaults. Go ahead and run `sudo apachectl restart` to pick up the new vhost and then you test it out by having curl resolve to that host name to your localhost:

```bash
curl http://local.example.com --resolve local.example.com:80:127.0.0.1
```

In order to allow your web browsers to know how to use this domain name, and to avoid having to manually tell curl what to do each time, you can add the following to the `/private/etc/hosts` file (edit it as root):

```ini
127.0.0.1 local.example.com
```

Now you should be able to go to [http://local.example.com](local.example.com) in your web browser.

## TLS

In order to let your browser feel nice and cozy by having a TLS certificate, the first thing you need to do is create one. So let's give it a home:

```bash
sudo mkdir -p /private/etc/apache2/tls
cd /private/etc/apache2/tls
```

For generating the actual certs, I used [cfssl](https://github.com/cloudflare/cfssl). To install it, you will need [Go](https://golang.org/doc/install), at which point you can run:

```bash
go get -u github.com/cloudflare/cfssl/cmd/cfssl
go get -u github.com/cloudflare/cfssl/cmd/cfssljson
```

With cfssl installed, now let's create our root certificate authority:

```bash
cat <<EOF | cfssl genkey -initca - | sudo cfssljson -bare ca
{
    "CN": "localhost Root CA",
    "hosts": [],
    "key": { "algo": "rsa", "size": 4096},
    "names": [
        {
            "C": "US",
            "ST": "Michigan",
            "L": "Lansing",
            "O": "Digestible DevOps",
            "OU": "localhost"
        }
    ]
}
EOF
```

You should now see `ca-key.pem` and `ca.pem` in the `/private/etc/apache2/tls` folder. If you are curious you see the details of the resulting public key with the following:

```bash
openssl x509 -in ca.pem -text -noout
```

You can add trust to this cert to your Keychain Access certificates, or follow whatever method is needed to install the cert for your preferred browser in order to make things smoother when browsing you the domain you set up. For Keychain Access:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /etc/apache2/tls/ca.pem
```

Now you need a server cert, signed by the root CA, and valid for 397 days (9528 hours):

```bash
cat > /tmp/ca-config.json <<EOF
{
  "signing": {
    "profiles": {
      "server": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "9528h"
      }
    }
  }
}
EOF

# Add any additional domain names here
HOSTNAME_LIST='"localhost", "*.example.com"'

SERVER_CSR="$(cat <<EOF | sudo cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=/tmp/ca-config.json -profile=server -
{
    "CN": "localhost",
    "hosts": [ ${HOSTNAME_LIST} ],
    "key": { "algo": "rsa", "size": 2048 },
    "names": [
        {
            "C": "US",
            "ST": "Michigan",
            "L": "Lansing",
            "O": "Digestible DevOps",
            "OU": "localhost"
        }
    ]
}
EOF
)"

echo "${SERVER_CSR}" | sudo cfssljson -bare server
```

Now you have `server-key.pem` and `server.pem`, which will be used directly by Apache, once we configure Apache to do so. Now the file `/private/etc/apache2/httpd.conf` needs to be modified to enable TLS. Once again you need to edit the file as root, making sure that the following line are present and uncommented (no # at the start of the line):

```ini
LoadModule socache_shmcb_module libexec/apache2/mod_socache_shmcb.so
LoadModule ssl_module libexec/apache2/mod_ssl.so
Include /private/etc/apache2/extra/httpd-ssl.conf
```

Now we need to modify the file `/private/etc/apache2/extra/httpd-ssl.conf`, also as root, to set up the paths to the cert files so that you end up with the following lines:

```ini
Listen 443
SSLCertificateFile "/private/etc/apache2/tls/server.pem"
SSLCertificateKeyFile "/private/etc/apache2/tls/server-key.pem"
```

Test that the configuration is at least syntactically correct:

```bash
sudo apachectl configtest
```

If you see `Syntax OK` at the end of that, you are good, so go ahead and restart Apache

```bash
sudo apachectl restart
```

With the generic Apache config on Mac, you should be able to go to [https://localhost/](https://localhost/) (or the domain we set up earlier: [https://local.example.com/](https://local.example.com/)) and see the "It Works!" banner. If not, e.g. you see "connection refused" or something like that, look at the error logs as you load the page:

```bash
sudo tail -f -n20 /var/log/apache2/error_log
```

## Reverse Proxy

The last step here is setting up the reverse proxy. Sometimes this is referred to as just a proxy, but there are differences between a proxy and a reverse proxy. A network proxy is something you knowingly connect use in order to connect to something else, for example a corporate network may use a Squid proxy to only allow certain internet traffic, so you configure your system to use that server as a proxy so that you ask it to, for example, handle a request to github.com, whereas with a reverse proxy, you go to the site that you want, but that "edge" web server then decides to actually send your request to another web server. If you had several Node services running on various ports on a single server, you could set up a reverse proxy to send requests to specific services based on the URI path, etc., but the end user would see it all as one logical service.

To enable the reverse proxy capabilities in the Apache web server, we will again need to edit the `/private/etc/apache2/httpd.conf` file as root, this time uncommenting or adding the following:

```ini
LoadModule xml2enc_module libexec/apache2/mod_xml2enc.so
LoadModule proxy_html_module libexec/apache2/mod_proxy_html.so
LoadModule proxy_module libexec/apache2/mod_proxy.so
LoadModule proxy_connect_module libexec/apache2/mod_proxy_connect.so
LoadModule proxy_http_module libexec/apache2/mod_proxy_http.so
Include /private/etc/apache2/extra/proxy-html.conf
```

Now we will configure the actual revers proxy, but rather than mess with the `proxy-html.conf` file, we'll modify `httpd-vhosts.conf`, by editing (as root) `/private/etc/apache2/extra/httpd-vhosts.conf` to change our previous:

```xml
<VirtualHost *:443>
    ServerName local.example.com
    SSLEngine On
    SSLCertificateFile /private/etc/apache2/tls/server.pem
    SSLCertificateKeyFile /private/etc/apache2/tls/server-key.pem
    SSLProxyEngine On
    ProxyRequests Off
    ProxyVia Off
    <Proxy *>
         Require all granted
    </Proxy>
    ProxyPass "/example"  "http://www.example.com/"
    ProxyPassReverse "/example"  "http://www.example.com/"
    ProxyPass "/domains/reserved" "https://www.iana.org/domains/reserved"
    ProxyPassReverse "/domains/reserved" "https://www.iana.org/domains/reserved"
</VirtualHost>
```

Now we restart the web server once again:

```bash
sudo apachectl restart
```

This change will cause the [`/`](https://local.example.com) path to behave the same as before, but now the [`/example`](http://local.example.com/example) and [`/domains/reserved`](http://local.example.com/domains/reserved) paths will use the reverse proxy.

However... we see that the iana reverse proxy has some missing resources, because it assumes some absolute paths. This will not be uncommon. To figure out the paths that are needed, you can go to your local site in a browser and open the developer console and look at the errors. In this case, the following reverse proxies would need to be set up (just add them into the same VirtualHost element):

```xml
    ProxyPass "/_css" "https://www.iana.org/_css"
    ProxyPassReverse "/_css" "https://www.iana.org/_css"
    ProxyPass "/_js" "https://www.iana.org/_js"
    ProxyPassReverse "/_js" "https://www.iana.org/_js"
    ProxyPass "/_img" "https://www.iana.org/_img"
    ProxyPassReverse "/_img" "https://www.iana.org/_img"
```

Even though you can muscle your way through resolving conflicts like this, it will probably be easier by just mapping the reverse proxy from root, to root, when setting up a reverse proxy to what would have been an external site. Perhaps a better example of a setup that would use multiple reverse proxies would be the previously described scenario of having several microservices, each running on a different port, which could be represented by something like this:

```xml
<VirtualHost *:443>
    ServerName local.example.com
    SSLEngine On
    SSLCertificateFile /private/etc/apache2/tls/server.pem
    SSLCertificateKeyFile /private/etc/apache2/tls/server-key.pem
    SSLProxyEngine On
    SSLProxyVerify None
    SSLProxyCheckPeerCN Off
    SSLProxyCheckPeerName Off
    ProxyRequests Off
    ProxyVia Off
    <Proxy *>
         Require all granted
    </Proxy>
    ProxyPass "/"  "http://localhost:8080/"
    ProxyPassReverse "/"  "http://localhost:8080/"
    ProxyPass "/auth" "http://localhost:8081"
    ProxyPassReverse "/auth" "http://localhost:8081"
    ProxyPass "/api" "http://localhost:8082"
    ProxyPassReverse "/api" "http://localhost:8082"
    ProxyPass "/cache" "http://localhost:8083"
    ProxyPassReverse "/cache" "http://localhost:8083"
</VirtualHost>
```

## Conclusion

This is a strategy that I have found many, many uses for. Hopefully you have found something useful here as well.
