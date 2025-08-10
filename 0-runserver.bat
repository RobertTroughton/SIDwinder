@echo off
cd public

@echo server now running at http://localhost:8000/

python -m http.server 8000

