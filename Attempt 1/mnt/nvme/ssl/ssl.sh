$URL="<subdomain>.duckdns.org"

echo "Copying certificates to /mnt/nvme/ssl/"
cp /mnt/nvme/swag/etc/letsencrypt/live/"$URL"/fullchain.pem /mnt/nvme/ssl/fullchain.pem
cp /mnt/nvme/swag/etc/letsencrypt/live/"$URL"/privkey.pem /mnt/nvme/ssl/privkey.pem


