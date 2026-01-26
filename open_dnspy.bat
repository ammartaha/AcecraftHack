@echo off
echo Opening dnSpy to decompile WeGame.Battle.Logic.bytes...
echo.
echo Once dnSpy opens:
echo 1. The file should load automatically
echo 2. Look in the left panel for the assembly tree
echo 3. Navigate to: WE.Battle.Logic namespace
echo 4. Find the PlayerLogic class
echo.
start "" "tools\dnSpy\dnSpy.exe" "acecraft files\Documents\dragon2019\assets\Hybrid\WeGame.Battle.Logic.bytes"
