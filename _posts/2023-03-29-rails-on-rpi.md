---
layout: post
title: Running a Rails app from your home
summary: How to run a Rails application on RaspberryPI and expose it to the internet
date: 2023-03-29 18:03
categories: ruby
published: true
---

You should never run any serious applications from your local network. Never ever allow public
access into your home network. If you absolutely must, use a VPN. But if you like to live
dangerously, read on.

This post is mostly documentation for my future self. I have a small private application that I
want to be able to access even when I'm not home. It's not that important so that I want to pay
for a VPS and as I have some spare RaspberryPIs, I decided to finally use them for something.

## Prerequisites

<ul class="list-disc">
  <li>
    A computer within a private network without a static IPv4 address. In this case, a RaspberryPI.
  </li>
  <li>
    A VPS with a static IPv4 address, used only as a jump-off point.
  </li>
</ul>

## Overview

The first step is to deploy the application to the RaspberryPI. There are a lot of ways to do it - I prefer using capistrano and will document it in a follow-up post. Our app can be served on
any port and in our case this will be `80`.

The second step is to set up your domain with your public VPS. Create an
`A` DNS record that points to its IPv4.

For proxying the traffic between the two machines, we'll use <a
href="https://github.com/fatedier/frp" target="_blank">FRP</a>. FRP is a reverse proxy that's
designed for exposing local services to the Internet. You can also use it to create a service
similar to ngrok if you need to expose your development servers to the Internet. This is
particularly useful if you need to test webhooks or oAuth integration with a third-party API.

FRP has a server and a client component that are part of the same package. We'll run an FRP
server on the VPS and the FRP client on our RaspberryPI.

## Setting up the FRP server

Start by installing `FRP` on your VPS. We'll put the executables in our home folder. `FRP` needs a
simple config file that tells it on what port it will receive the requests and a second port that
will be used by the FRP client. Place the `frps.ini` in the home directory as well
with the following contents:

```ini
[common]
; this is the port where the FRP client will connect to the FRP server
bind_port = 7000

; this is where we'll proxy the requests from our server
vhost_http_port = 8080
```

Start the FRP server by running the following command in the shell:

```sh
frps -c frps.ini
```

Running it in the shell is a good way to test things out but ultimately we want the run the server
in a more-robust (robuster?) way.

### Manage the FRP server with systemd

`systemd` is the standard way to run services on UNIX machines. Start by creating a service file
for our server in `/etc/systemd/system/frps.service`:

```ini
[Unit]
Description = frp server
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
ExecStart = /home/deploy/frps -c /home/deploy/frps.ini
Restart=always
RestartSec=3
TimeoutStartSec=300
TimeoutStopSec=Infinity

[Install]
WantedBy = multi-user.target
```

Enable the service and start it by executing the following commands:

```sh
systemctl enable frps.service
systemctl start frps.service
```

Use `sudo` if your current user doesn't have the necessary permissions. If all is good, the FRP
server will be started on machine boot and will be restarted automatically if it fails for any
reason.

Next, we'll tell our web server (nginx) to proxy incoming requests to the FRP server.

### Setting up nginx

You can use any other web server as long as it can proxy requests to a unix socket or a different
port. Nginx is great for this use-case and we'll use it here.

After installing nginx, we need to set it up to proxy incoming requests to the FRP server. Create a
file in the `/etc/nginx/sites-enabled` folder with the following contents:

```nginx
# /etc/nginx/sites-enabled/example

server {
  listen 80;
  listen 443;
  listen [::]:80;

  server_name example.net;

  location / {
    proxy_pass http://0.0.0.0:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header REMOTE-HOST $remote_addr;
    proxy_set_header origin 'http://example.net';
  }
}
```

Make sure to point the `proxy_pass` directive to the same port we defined in the `frps.ini` file
above with the `vhost_http_port` line - `8080` in our case.

At this point, we may need to reload `nginx` for the changes to take effect:

```sh
systemctl reload nginx.service
```

This is all we need to set up on the VPS.

## Setting up the FRP server

Next, we'll jump over to the RaspberryPI for the rest of the setup. Install `FRP` and
create the client configuration file `/home/deploy/frps.ini`:

```ini
[common]
; The public IP of our VPS
server_addr = x.x.x.x

; The port of the FRP server we defined as `bind_port` in the server configuration
server_port = 7000

[web]
type = http

; The port of our local web server where we serve the Rails application
local_port = 80
custom_domains = example.net
```

Same as on the VPS, we'll use `systemd` to manage the FRP client. Create
`/etc/systemd/system/frpc.service` with the following contents:

```ini
[Unit]
Description = frp client
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
ExecStart = /home/deploy/frpc -c /home/deploy/frpc.ini
Restart=always
RestartSec=3

[Install]
WantedBy = multi-user.target
```

Note that we use `frpc` for the client and `frps` for the server. Not that I messed them up one too
many times 😬.

Again, enable and start the service:

```sh
systemctl enable frpc.service
systemctl start frpc.service
```

If you set up your Rails application properly, it will now start receiving traffic from your domain
:). A common mistake is making sure the app is aware of the public host (e.g. `example.net`). If
you want to use SSL, you'll need to make some minor changes to the config files and expand your
nginx config but this is out of the scope here.

You may have noticed that there's nothing Rails-specific about this. You are correct! My plan is to
write a couple more posts that go into the spefics on how to deploy and serve a Rails application
in the simplest way possible and this will tie in nicely with them.
