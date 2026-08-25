#!/usr/bin/env bash
# SL TV Sync - Setup rapido
# Uso: ./setup.sh

set -e

echo "SL TV Sync - Setup"
echo "===================="

if [ ! -f .env ]; then
  cp .env.example .env
  echo ".env criado a partir do .env.example"
fi

if [ ! -d node_modules ]; then
  echo "Instalando dependencias..."
  npm install
fi

echo ""
echo "Iniciando servidor..."
echo "Dashboard: http://localhost:3000/dashboard.html"
echo "TV Player: http://localhost:3000/"
npm start
