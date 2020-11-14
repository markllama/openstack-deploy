#!/bin/bash

sudo mkdir -p /opt/coredns

cat <<EOF > /opt/coredns/Corefile
.:53 {
     bind 172.16.3.2
     forward . 192.168.1.1
}
EOF

sudo docker run -d --name coredns \
  --net=host --restart always \
  --volume /opt/coredns/:/root \
  -p 172.16.3.2:53:53 \
  coredns/coredns --conf /root/Corefile 



