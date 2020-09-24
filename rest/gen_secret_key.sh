#!/bin/bash

KEY=$(python3 -c 'import os; print(os.urandom(32).hex())')
sed -i "s/FLASK_SECRET_KEY/$KEY/" .env
