@echo off
echo =========================================
echo Automatizacion de GitHub - Subir Cambios
echo =========================================
echo.

echo 1. Anadiendo archivos a Git...
git add .
echo.

set /p desc="2. Ingresa el mensaje de tu commit: "
if "%desc%"=="" (
    echo El mensaje del commit no puede estar vacio.
    pause
    exit /b
)

echo.
echo 3. Creando el Commit...
git commit -m "%desc%"
echo.

echo 4. Subiendo a GitHub...
git push

echo.
echo =========================================
echo ¡Proceso finalizado exitosamente!
echo =========================================
pause
