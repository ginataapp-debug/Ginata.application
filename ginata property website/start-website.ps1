# Serves the Ginata website and web app at http://localhost:3000 (an origin the Ginata API accepts).
Set-Location -LiteralPath $PSScriptRoot
Start-Process "http://localhost:3000/"
python -m http.server 3000 --bind 127.0.0.1
