@echo off
cd /d "C:\Users\svrprevi\Desktop\meteocarnet-mali-serveur\server"
if not exist "C:\Users\svrprevi\Desktop\meteocarnet-mali-serveur\logs" mkdir "C:\Users\svrprevi\Desktop\meteocarnet-mali-serveur\logs"
"C:\Program Files\nodejs\node.exe" server.js >> "C:\Users\svrprevi\Desktop\meteocarnet-mali-serveur\logs\out.log" 2>> "C:\Users\svrprevi\Desktop\meteocarnet-mali-serveur\logs\err.log"
