git config --global user.name "Sichacvah"
git config --global user.email "sichirc@gmail.com"
mkdir ~/.aws
touch ~/.aws/helga_candys.yml
echo access_key_id: $AWS_ACCESS_KEY >> ~/.aws/helga_candys.yml
echo secret_access_key: $AWS_SECRET >> ~/.aws/helga_candys.yml
