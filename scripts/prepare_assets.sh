set -e
cd apps/boruta_admin/assets
npm ci
npm run build
cd ../
mix phx.digest
cd ../boruta_identity
mix phx.digest
cd ../boruta_web
mix phx.digest
cd ../..
