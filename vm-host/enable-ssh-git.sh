#!/bin/bash

ssh-keygen -R lab
ssh-copy-id -o PreferredAuthentications=password lab
scp ~/.ssh/markllama@gmail.com_rsa lab:.ssh
grep -A1 github.com ~/.ssh/config | ssh lab tee -a .ssh/config
ssh lab chmod 600 .ssh/*
cat ~/.gitconfig | ssh lab tee .gitconfig
