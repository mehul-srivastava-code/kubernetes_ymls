read -p "enter new file name" filename
mkdir -p "$filename"
touch "$filename/deployment.yml"
cp new_basic/deployment.yml "$filename/deployment.yml"
touch "$filename/cluster.yml"
cp new_basic/cluster.yml "$filename/cluster.yml"
echo "setup for $filename created"
