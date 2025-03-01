#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout dashboard.key -x509 -days 3650 -out dashboard.crt -subj "/C=CN/L=Beijing/O=lisea/CN=dashbaord"

openssl req -newkey rsa:4096 -nodes -sha256 -keyout server.key -out server.csr -subj "/C=CN/L=Beijing/O=lisea/CN=k8s.dashbaord.com"

openssl x509 -req -days 3650 -in server.csr -CA dashboard.crt -CAkey dashboard.key -CAcreateserial -extfile extfile.cnf -out server.crt
