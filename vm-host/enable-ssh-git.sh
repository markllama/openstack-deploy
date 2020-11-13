#!/bin/bash

 : ${REMOTE_USER:=stack}

ssh-keygen -R lab
ssh-copy-id -o PreferredAuthentications=password ${REMOTE_USER}@lab
scp ~/.ssh/markllama@gmail.com_rsa ${REMOTE_USER}@lab:.ssh
grep -A1 github.com ~/.ssh/config | ssh ${REMOTE_USER}@lab tee -a .ssh/config
ssh ${REMOTE_USER}@lab chmod 600 .ssh/*
cat ~/.gitconfig | ssh ${REMOTE_USER}@lab tee .gitconfig
