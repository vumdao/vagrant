vagrant destroy node1 -f
vagrant destroy node2 -f
rm  -rf .vagrant
sudo rm -rf shared/replica/*
vagrant up
