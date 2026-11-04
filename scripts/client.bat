@echo off
rem Avvia un guest su Windows senza WSL. Uso: client.bat [nome]
rem La prima volta prepara l'ambiente Python in .venv-win e, se Python
rem non e' installato, scarica l'ultima versione da python.org.
setlocal
pushd "%~dp0.."
set "PYTHON=.venv-win\Scripts\python.exe"
if exist "%PYTHON%" goto :dipendenze

rem "python" puo' essere la scorciatoia verso lo Store: va provato davvero.
set "BASE="
call python -c "import venv" >nul 2>&1
if not errorlevel 1 set "BASE=python"
if not defined BASE call :cerca_installato
if defined BASE goto :crea_ambiente

echo Python non trovato: scarico l'ultima versione da python.org...
set "INSTALLER=%TEMP%\python-ultima-amd64.exe"
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$page=Invoke-WebRequest -UseBasicParsing 'https://www.python.org/downloads/windows/';" ^
  "$v=[regex]::Match($page.Content,'Latest Python 3 Release - Python ([0-9.]+)').Groups[1].Value;" ^
  "if(-not $v){throw 'Versione di Python non trovata'};" ^
  "Write-Host ('Versione: '+$v);" ^
  "Invoke-WebRequest -UseBasicParsing -OutFile $env:INSTALLER ('https://www.python.org/ftp/python/'+$v+'/python-'+$v+'-amd64.exe');" ^
  "$s=Get-AuthenticodeSignature $env:INSTALLER;" ^
  "if($s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notmatch 'Python Software Foundation'){throw 'Firma del file non valida'}"
if errorlevel 1 goto :errore_installazione

echo Installazione di Python (solo per il tuo utente)...
start "" /wait "%INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0 Include_test=0
if errorlevel 1 goto :errore_installazione
del "%INSTALLER%" 2>nul
rem Questa finestra non vede ancora il nuovo PATH: cerco Python nella sua cartella.
call :cerca_installato
if not defined BASE goto :errore_installazione

:crea_ambiente
echo Preparazione dell'ambiente Python...
call "%BASE%" -m venv .venv-win
if errorlevel 1 goto :errore

:dipendenze
"%PYTHON%" -c "import websockets, dotenv" 2>nul
if not errorlevel 1 goto :nome
"%PYTHON%" -m pip install --quiet --disable-pip-version-check websockets python-dotenv
if errorlevel 1 goto :errore

:nome
set "NOME=%~1"
:chiedi
if not "%NOME%"=="" goto :avvia
set /p "NOME=Nome: "
if errorlevel 1 goto :errore
goto :chiedi

:avvia
"%PYTHON%" backend\client.py "%NOME%"
if errorlevel 1 goto :errore
popd
exit /b 0

:cerca_installato
for /d %%d in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
  if exist "%%d\python.exe" set "BASE=%%d\python.exe"
)
exit /b 0

:errore_installazione
del "%INSTALLER%" 2>nul
echo.
echo Installazione automatica di Python non riuscita.
echo Installalo a mano da https://www.python.org/downloads/ e riprova.
goto :fine_errore

:errore
echo.
echo Qualcosa non ha funzionato: controlla il messaggio qui sopra.
echo Il server deve essere avviato.

:fine_errore
popd
pause
exit /b 1
