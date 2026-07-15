################################################################################
# Bastion Module — Secure Jump Host with SSM
################################################################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── Bastion EC2 Instance ────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name

  # SSM access — no SSH key needed
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-ssm-agent postgresql15
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Harden SSH
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    systemctl restart sshd

    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CONFIG'
    {
      "metrics": {
        "metrics_collected": {
          "mem": { "measurement": ["mem_used_percent"] },
          "disk": { "measurement": ["used_percent"], "resources": ["*"] }
        }
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              { "file_path": "/var/log/secure", "log_group_name": "/bastion/secure" },
              { "file_path": "/var/log/messages", "log_group_name": "/bastion/messages" }
            ]
          }
        }
      }
    }
    CONFIG
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s
  EOF
  )

  tags = {
    Name = "${var.name_prefix}-bastion"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ─── Elastic IP (optional) ───────────────────────────────────────────────────

resource "aws_eip" "bastion" {
  count    = var.assign_eip ? 1 : 0
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-bastion-eip"
  }
}
