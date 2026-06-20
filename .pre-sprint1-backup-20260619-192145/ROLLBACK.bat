@echo off
echo === Klasivo Pre-Sprint 1 Rollback ===
echo.
echo This will reset your repo to the pre-Sprint 1 snapshot.
echo ALL Sprint 1 changes will be lost.
echo.
pause
echo.
echo Rolling back to: 0143414 (tag: pre-sprint1-20260619-192145)
echo.
git checkout main
git reset --hard pre-sprint1-20260619-192145
git push origin main --force
echo.
echo Deploying the rolled-back state to Firebase...
firebase deploy --only functions,firestore:rules,firestore:indexes
echo.
echo Rollback complete.
pause
