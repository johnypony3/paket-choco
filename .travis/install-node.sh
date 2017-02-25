#!/bin/sh

. $HOME/.nvm/nvm.sh
nvm install stable
nvm use stable

node --version

npm install

npm install glob -S
npm install nuget-push -S
