#!/bin/bash

 : ${REMOTE_HOST:=director.lab}
 : ${REMOTE_USER:=stack}

ssh-keygen -R ${REMOTE_HOST}
ssh-copy-id -o PreferredAuthentications=password ${REMOTE_USER}@${REMOTE_HOST}
scp ~/.ssh/markllama@gmail.com_rsa ${REMOTE_USER}@${REMOTE_HOST}:.ssh
grep -A1 github.com ~/.ssh/config | ssh ${REMOTE_USER}@${REMOTE_HOST} tee -a .ssh/config
ssh ${REMOTE_USER}@${REMOTE_HOST} chmod 600 .ssh/\*
cat ~/.gitconfig | ssh ${REMOTE_USER}@${REMOTE_HOST} tee .gitconfig
