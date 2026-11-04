@echo off
setlocal EnableExtensions
set "SIM_DRIVE="
for %%D in (Z Y X W V U T S R Q P O N M L K J I H G F) do if not exist %%D:\ set "SIM_DRIVE=%%D:"
if not defined SIM_DRIVE (
    echo ERROR: No free drive letter available for the temporary ASCII path.
    exit /b 2
)
subst %SIM_DRIVE% "%~dp0"
if errorlevel 1 (
    echo ERROR: Could not create the temporary drive mapping.
    exit /b 3
)
pushd %SIM_DRIVE%\
if errorlevel 1 (
    subst %SIM_DRIVE% /d
    echo ERROR: Could not enter the temporary drive mapping.
    exit /b 4
)
vsim -modelsimini modelsim.ini -c -do sim/run_modelsim.do
set "SIM_RC=%ERRORLEVEL%"
popd
subst %SIM_DRIVE% /d
exit /b %SIM_RC%
