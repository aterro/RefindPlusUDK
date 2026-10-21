set NO_FASTFETCH=1
@echo off
REM Build-Refind.bat - Build rEFInd with CLANG38 toolchain
REM
REM Place this script in the edk2 root directory and run:
REM   Build-Refind.bat         - Build RELEASE (default)
REM   Build-Refind.bat RELEASE - Build RELEASE
REM   Build-Refind.bat REL     - Build RELEASE
REM   Build-Refind.bat DEBUG   - Build DEBUG
REM   Build-Refind.bat DBG     - Build DEBUG
REM   Build-Refind.bat NOOPT   - Build NOOPT
REM   Build-Refind.bat NPT     - Build NOOPT
REM   Build-Refind.bat ALL     - Build all (RELEASE, DEBUG, NOOPT)

setlocal EnableExtensions EnableDelayedExpansion

REM Determine directories
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%"
set "EDK2_DIR=%ROOT_DIR%"
set "WORKSPACE=%EDK2_DIR%"
set "OUTPUT_DIR=%EDK2_DIR%\000-BOOTx64-Files"

set "BUILD_TYPE=%~1"
if not defined BUILD_TYPE set "BUILD_TYPE=RELEASE"

if /I "%BUILD_TYPE%"=="RELEASE" set "BUILD_TYPE=REL"
if /I "%BUILD_TYPE%"=="DEBUG" set "BUILD_TYPE=DBG"
if /I "%BUILD_TYPE%"=="NOOPT" set "BUILD_TYPE=NPT"

set "RUN_REL=0"
set "RUN_DBG=0"
set "RUN_NPT=0"

if /I "%BUILD_TYPE%"=="REL" (
  set "RUN_REL=1"
) else if /I "%BUILD_TYPE%"=="DBG" (
  set "RUN_DBG=1"
) else if /I "%BUILD_TYPE%"=="NPT" (
  set "RUN_NPT=1"
) else if /I "%BUILD_TYPE%"=="ALL" (
  set "RUN_REL=1"
  set "RUN_DBG=1"
  set "RUN_NPT=1"
) else (
  echo Unknown build type "%~1", defaulting to RELEASE.
  set "RUN_REL=1"
)

REM Ensure build directories exist
if not exist "%EDK2_DIR%\Build" mkdir "%EDK2_DIR%\Build"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

pushd "%EDK2_DIR%"

REM Set up environment using edksetup.bat to properly configure everything
call edksetup.bat

REM Set additional paths
set PATH=%EDK_TOOLS_BIN%;C:\Python27;C:\Python27\Scripts;C:\LLVM\bin;%PATH%
set PYTHON_HOME=C:\Python27
set PYTHONPATH=%EDK_TOOLS_PATH%\Source\Python

if "%RUN_REL%"=="1" (
  echo.
  echo ===== Building RELEASE with CLANG38 =====
  if exist "Build\Refind\RELEASE_CLANG38" rmdir /s /q "Build\Refind\RELEASE_CLANG38"
  call :do_build RELEASE REL
  if errorlevel 1 goto :build_failed
)

if "%RUN_DBG%"=="1" (
  echo.
  echo ===== Building DEBUG with CLANG38 =====
  if exist "Build\Refind\DEBUG_CLANG38" rmdir /s /q "Build\Refind\DEBUG_CLANG38"
  call :do_build DEBUG DBG
  if errorlevel 1 goto :build_failed
)

if "%RUN_NPT%"=="1" (
  echo.
  echo ===== Building NOOPT with CLANG38 =====
  if exist "Build\Refind\NOOPT_CLANG38" rmdir /s /q "Build\Refind\NOOPT_CLANG38"
  call :do_build NOOPT NPT
  if errorlevel 1 goto :build_failed
)

popd

echo.
echo Build complete!
echo   BOOTx64 files: %OUTPUT_DIR%
if "%RUN_REL%"=="1" echo   REL: %EDK2_DIR%\Build\Refind\RELEASE_CLANG38\X64
if "%RUN_DBG%"=="1" echo   DBG: %EDK2_DIR%\Build\Refind\DEBUG_CLANG38\X64
if "%RUN_NPT%"=="1" echo   NPT: %EDK2_DIR%\Build\Refind\NOOPT_CLANG38\X64
echo.
echo Build successful and files copied.
echo Press any key to open the output folder and exit.
pause >nul

start "" "%OUTPUT_DIR%"
endlocal
exit /b 0

:build_failed
popd
endlocal
exit /b 1

:do_build
set "TARGET=%~1"
set "TAG=%~2"
set "BUILD_DIR=Build\Refind\%TARGET%_CLANG38\X64"
set "BINARY_DIR=%EDK2_DIR%\%BUILD_DIR%"
set "OUTPUT_FILE=%OUTPUT_DIR%\Refind.efi"
if /I not "%TAG%"=="REL" set "OUTPUT_FILE=%OUTPUT_DIR%\Refind_%TAG%.efi"

C:\Python27\python.exe BaseTools\Source\Python\build\build.py -a X64 -b %TARGET% -t CLANG38 -p RefindPkg\RefindPkg.dsc
if errorlevel 1 (
  echo Build failed!
  exit /b 1
)

REM Fix for GenFw section classification bug: strip WRITE from .text section
REM Without this, old GenFw misclassifies .text as DATA due to -fpie adding SHF_WRITE
set "ELF_DLL=%BUILD_DIR%\RefindPkg\refind\DEBUG\refind.dll"
set "FIXED_DLL=%BUILD_DIR%\RefindPkg\refind\DEBUG\refind_fixed.dll"
set "OUTPUT_EFI=%BUILD_DIR%\refind.efi"

if exist "%ELF_DLL%" (
  echo.
  echo Fixing ELF .text section flags for GenFw...
  "C:\LLVM\bin\llvm-objcopy.exe" --set-section-flags .text=alloc,code,readonly "%ELF_DLL%" "%FIXED_DLL%"
  if errorlevel 1 exit /b 1
  echo Running GenFw on ELF file...
  "GenFw" -z -e UEFI_APPLICATION -o "%OUTPUT_EFI%" "%FIXED_DLL%"
  if errorlevel 1 exit /b 1
)

if not exist "%OUTPUT_EFI%" (
  echo Missing build output: %OUTPUT_EFI%
  exit /b 1
)

echo Copying %OUTPUT_FILE%...
copy /y "%OUTPUT_EFI%" "%OUTPUT_FILE%" >nul
if errorlevel 1 exit /b 1
echo   Copied: %OUTPUT_FILE%

call :rename_outputs "%BINARY_DIR%" "%TAG%"
if errorlevel 1 exit /b 1

exit /b 0

:rename_outputs
set "OUT_DIR=%~1"
set "TAG=%~2"

if not exist "%OUT_DIR%" exit /b 1

for %%F in ("%OUT_DIR%\*.efi") do (
  set "FILE_NAME=%%~nF"
  if /I "!FILE_NAME!"=="gptsync" (
    ren "%%~fF" "x64_%%~nF_%TAG%.efi"
  ) else if /I "!FILE_NAME!"=="refind" (
    ren "%%~fF" "x64_%%~nF_%TAG%.efi"
  ) else (
    ren "%%~fF" "DRIVER_%TAG%--x64_%%~nF.efi"
  )
  if errorlevel 1 exit /b 1
)

exit /b 0
