cd ../dist
(
  scp -P 20522 -r ./ root@192.168.1.2:/var/helios/Helios/Workspace/Admin/Public/
  scp -P 20522 -r ./index.html root@192.168.1.2:/var/helios/Helios/Workspace/Admin/Resources/Views/
)
