#!/bin/sh

python -m venv venv
source venv/bin/activate

if [ -f "requirements.txt" ]
then
    python -m pip install -r requirements.txt
else
    python -m pip install psycopg2
    python -m pip freeze > requirements.txt
fi

deactivate
