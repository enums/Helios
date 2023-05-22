cd ../dist
(
  scp -r ./ yuuzheng@192.168.1.10:/home/yuuzheng/Developer/Helios/Workspace/Admin/Public/
  scp -r ./index.html yuuzheng@192.168.1.10:/home/yuuzheng/Developer/Helios/Workspace/Admin/Resources/Views/
)
