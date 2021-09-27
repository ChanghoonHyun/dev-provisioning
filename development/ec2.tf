locals {
  terraform_version = "1.0.7"
  init_before_scripts = [
    "sudo amazon-linux-extras install epel -y",
    "sudo hostnamectl set-hostname chhyun-dev",
    "sudo adduser ${local.ec2_user}",
    "sudo su - -c \"echo '${local.ec2_user} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers\"",
    "sudo su - -c \"sudo mkdir -p /home/${local.ec2_user}/.ssh\"",
    //    "sudo su - -c \"sudo echo '${local.pem_public_content}' > /home/${local.ec2_user}/.ssh/authorized_keys\"",
    "sudo su - -c \"sudo cp /home/ec2-user/.ssh/authorized_keys /home/${local.ec2_user}/.ssh && sudo chown -R ${local.ec2_user} /home/${local.ec2_user}/.ssh/ && sudo chgrp -R ${local.ec2_user} /home/${local.ec2_user}/.ssh/\"",
    "sudo su - ${local.ec2_user} -c \"sudo chmod 700 /home/${local.ec2_user}/.ssh && sudo chmod 600 /home/${local.ec2_user}/.ssh/authorized_keys && sudo chmod 400 /home/${local.ec2_user}/.ssh/id_rsa\"",
  ]
  init_after_scripts = [
    "sudo chown -R $${USER} ~/.ssh/",
    "sudo chgrp -R $${USER} ~/.ssh/",
  ]
  provisioning_scripts = [
    "sudo yum install -y zsh git",
    "sudo sed -i \"s/bin\\/bash/usr\\/bin\\/zsh/\" /etc/passwd",
    "curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | bash",
    "sudo yum install -y bash-completion bash-completion-extras",
    "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k",
    "echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc",
    "sudo yum install --enablerepo=epel -y nodejs",
    "curl -s \"https://get.sdkman.io\" | bash",
    "wget https://releases.hashicorp.com/terraform/${local.terraform_version}/terraform_${local.terraform_version}_linux_amd64.zip",
    "unzip terraform_${local.terraform_version}_linux_amd64.zip",
    "sudo mv terraform /usr/local/bin/",
  ]

  append_provisioning_scripts = [
    "echo 1",
  ]
}

resource "aws_security_group" "development_chhyun_sg" {
  vpc_id      = local.vpc_id
  name        = "development_chhyun_sg"
  description = "development_chhyun_sg"

  ingress {
    cidr_blocks = local.allow_ips
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
  }

  ingress {
    cidr_blocks = local.allow_ips
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
  }
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 0
    protocol  = "all"
    to_port   = 0
  }
}

resource "aws_instance" "ec2" {
  ami           = "ami-08c64544f5cfcddd0"
  instance_type = "m5.xlarge"
  key_name      = local.pem_key_name
  subnet_id     = local.vpc_private_subnets[0]
  vpc_security_group_ids = [
    aws_security_group.development_chhyun_sg.id
  ]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(local.pem_key_path)
    host        = self.private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "whoami",
    ]
  }

  tags = local.default_tags
}

resource "null_resource" "init_before" {
  depends_on = [
    aws_instance.ec2
  ]

  triggers = {
    ec2 = aws_instance.ec2.private_dns
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "remote-exec" {
    inline = local.init_before_scripts
  }
}

resource "null_resource" "init_copy_id_rsa" {
  depends_on = [
    null_resource.init_before,
  ]

  triggers = {
    ec2 = aws_instance.ec2.private_dns
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "file" {
    source      = "files/id_rsa"
    destination = "~/.ssh/id_rsa"
  }
}

resource "null_resource" "init_copy_id_rsa_pub" {
  depends_on = [
    null_resource.init_before,
  ]

  triggers = {
    ec2 = aws_instance.ec2.private_dns
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "file" {
    source      = "files/id_rsa.pub"
    destination = "~/.ssh/id_rsa.pub"
  }
}

resource "null_resource" "init_after" {
  depends_on = [
    null_resource.init_before,
  ]

  triggers = {
    ec2 = aws_instance.ec2.private_dns
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "remote-exec" {
    inline = local.init_after_scripts
  }
}

resource "null_resource" "provisioning" {
  depends_on = [
    null_resource.init_after,
  ]

  triggers = {
    ec2 = aws_instance.ec2.private_dns
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "remote-exec" {
    inline = local.provisioning_scripts
  }
}

resource "null_resource" "provisioning_append" {
  depends_on = [
    null_resource.provisioning,
  ]

  triggers = {
    script_sha = sha256(join(", ", local.append_provisioning_scripts))
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "remote-exec" {
    inline = local.append_provisioning_scripts
  }
}

resource "null_resource" "p10k" {
  depends_on = [
    null_resource.provisioning_append,
  ]

  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "file" {
    source      = "files/.p10k.zsh"
    destination = "~/.p10k.zsh"
  }
}

resource "null_resource" "zsh" {
  depends_on = [
    null_resource.provisioning_append,
  ]

  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    user        = local.ec2_user
    private_key = file(local.pem_key_path)
    host        = aws_instance.ec2.private_ip
  }

  provisioner "file" {
    source      = "files/.zshrc"
    destination = "~/.zshrc"
  }
}
